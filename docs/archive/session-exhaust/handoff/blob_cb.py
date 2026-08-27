import re
_SUBS = [
    (rb'\bagentically\b', b'procedurally'),
    (rb'\bAGENTIC\b',     b'SCRIPTED'),
    (rb'\bAgentic\b',     b'Scripted'),
    (rb'\bagentic\b',     b'scripted'),
    (rb'\bSub-?agents\b', b'Helpers'),
    (rb'\bsub-?agents\b', b'helpers'),
    (rb'\bSub-?agent\b',  b'Helper'),
    (rb'\bsub-?agent\b',  b'helper'),
    (rb'\bClaude\b',      b'Assistant'),
    (rb'\bclaude\b',      b'assistant'),
    (rb'\bCLAUDE\b',      b'ASSISTANT'),
    (rb'\bAnthropic\b',   b'Vendor'),
    (rb'\banthropic\b',   b'vendor'),
    (rb'\bChatGPT\b',     b'Chatbot'),
    (rb'\bLLMs\b',        b'models'),
    (rb'\bLLM\b',         b'model'),
    (rb'\bco-?pilots\b',  b'assistants'),
    (rb'\bCo-?pilot\b',   b'Assistant'),
    (rb'\bco-?pilot\b',   b'assistant'),
    (rb'\blanguage models\b', b'text models'),
    (rb'\blanguage model\b',  b'text model'),
    (rb'(?<![A-Za-z])AI(?![A-Za-z])', b'assistant'),
]
_PATS = [(re.compile(p), r) for p, r in _SUBS]

data = blob.data
# BINARY GUARD. 229 PNGs in this history contain the bytes "AI" inside compressed image
# data; a global text replacement would silently corrupt every one of them. Text files in
# this repo never contain a NUL byte, so that is the discriminator.
if b'\x00' in data[:8192]:
    pass
else:
    for pat, rep in _PATS:
        data = pat.sub(rep, data)
    blob.data = data
