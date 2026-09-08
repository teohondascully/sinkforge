"""Opt-in MCP stdio pilot: python3 playtest/step_tool.py --session /absolute/owned/session.

One server owns one seat; do not also send command.py inputs to that seat. Returns original PNG bytes
and player-only fields in one tools/call response. No model configuration or live seat is auto-started.
Implements the small initialize/tools subset of MCP 2025-11-25 (not newer stateless revisions).
"""
import argparse
import base64
import fcntl
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PLAYER_FIELDS = ('id','screenshot','sim_seconds','error','capture_error')
COMMAND_FIELDS = {'ticks','keys','mouse','buttons','moves','settle','until','quit'}
VERSIONS = {'2024-11-05','2025-03-26','2025-06-18','2025-11-25'}
TOOL = {'name':'play_step','description':'Send physical input to this seat and see the resulting original frame.',
        'inputSchema':{'type':'object','properties':{
            'command':{'type':'object','properties':{
                'ticks':{'type':'integer','minimum':1},'keys':{'type':'array','items':{'type':'string'}},
                'mouse':{'type':'array','items':{'type':'number'},'minItems':2,'maxItems':2},
                'buttons':{'type':'array','items':{'type':'integer'}},
                'moves':{'type':'array','items':{'type':'object'}},'settle':{'type':'boolean'},
                'until':{'enum':['ticks','event']},'quit':{'type':'boolean'}},'additionalProperties':False},
            'note':{'type':'string'}},'required':['command'],'additionalProperties':False},
        'annotations':{'readOnlyHint':False,'destructiveHint':True,'idempotentHint':False,'openWorldHint':False}}


def image_content(session, response):
    path = Path(response['screenshot']).resolve()
    number = response['id']
    if type(number) is not int or path.parent != Path(session).resolve() or path.name != f'frame_{number:04d}.png':
        raise ValueError('capture is not this response frame in the owned session')
    if path.stat().st_size > 32 * 1024 * 1024:
        raise ValueError('capture exceeds pilot size limit')
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('capture is not a PNG')
    return {'type':'image','mimeType':'image/png','data':base64.b64encode(data).decode('ascii')}


def step(session, command, note='', timeout=120):
    try:
        if not isinstance(command,dict) or set(command)-COMMAND_FIELDS:
            raise ValueError('only physical input commands are accepted')
        if not isinstance(note,str) or len(note)>4096:
            raise ValueError('note must be text of at most 4096 characters')
        process = subprocess.run([sys.executable,str(HERE/'command.py'),str(session),json.dumps(command),
                                  '--timeout',str(timeout),'--note',note],capture_output=True,text=True,timeout=timeout+5)
        if process.returncode != 0:
            # Diagnostics stay in local artifacts; never forward traceback/state to the actor.
            raise ValueError('input/capture failed; evaluator should inspect the session artifacts')
        response = json.loads(process.stdout)
        shown = {k:response[k] for k in PLAYER_FIELDS if k in response}
        content = [{'type':'text','text':json.dumps(shown)}]
        if not command.get('quit'):
            content.append(image_content(session,shown))
        return {'content':content,'isError':False}
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired):
        return {'content':[{'type':'text','text':'Step failed or capture invalid; evaluator must inspect local artifacts before retrying.'}],
                'isError':True}


class Server:
    def __init__(self, session):
        self.session = session
        self.initialized = False
        self.ready = False

    def handle(self, request):
        if not isinstance(request,dict) or request.get('jsonrpc') != '2.0':
            return {'jsonrpc':'2.0','id':None,'error':{'code':-32600,'message':'Invalid request'}}
        number = request.get('id')
        method = request.get('method')
        if 'id' not in request:
            if method == 'notifications/initialized' and self.initialized:
                self.ready = True
            return None
        response = {'jsonrpc':'2.0','id':number}
        params = request.get('params',{})
        if not isinstance(params,dict):
            response['error']={'code':-32602,'message':'Invalid params'}
        elif method == 'initialize' and not self.initialized:
            version = params.get('protocolVersion')
            self.initialized = True
            response['result']={'protocolVersion':version if version in VERSIONS else '2025-11-25',
                                'capabilities':{'tools':{}},'serverInfo':{'name':'sinkforge-seat','version':'0.1.0'}}
        elif method == 'ping':
            response['result']={}
        elif not self.ready:
            response['error']={'code':-32000,'message':'Initialize first'}
        elif method == 'tools/list':
            response['result']={'tools':[TOOL]}
        elif method == 'tools/call' and params.get('name') == 'play_step':
            args = params.get('arguments',{})
            if not isinstance(args,dict) or set(args)-{'command','note'} or 'command' not in args:
                response['error']={'code':-32602,'message':'Invalid tool arguments'}
            else:
                response['result']=step(self.session,args['command'],args.get('note',''))
        else:
            response['error']={'code':-32601,'message':'Unknown method or tool'}
        return response


def serve(session):
    # Lock only other pilot servers. Legacy command.py users must respect exclusive seat ownership.
    with (session/'.step_tool.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        server = Server(session)
        for line in sys.stdin:
            try:
                reply=server.handle(json.loads(line))
            except ValueError:
                reply={'jsonrpc':'2.0','id':None,'error':{'code':-32700,'message':'Parse error'}}
            if reply is not None:
                print(json.dumps(reply),flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session',type=Path,required=True)
    args=parser.parse_args()
    if not args.session.is_dir():
        parser.error('session directory must already exist')
    serve(args.session.resolve())
