extends RefCounted
## THE SHAFT-REPLAY GOLDEN: the 200 checkpoint hashes `tests/test_shaft_replay_determinism.gd` pins, and
## the note of every re-pin since the array moved here (2026-09-05, at that file's 400-line cap). The
## rules are in the suite's header and are not repeated: captured from CI's pinned Linux build, never from
## a developer machine; a move from checkpoint 0 is a world change; both discriminators read off the run.
##
## **RE-PINNED 2026-09-12 for the queue's worldgen commits ahead of main** -- the d3-d7 ladder's strata
## and material records (D0628) and P044's shared bedding warp (D0629) both reach the generator before a
## cell is written, and P035's lip mantle (D0631) moves the body's own traversal -- so the array moves
## from checkpoint **0**, the generation-change shape. Harvested from CI's pinned Linux build (run
## 34721500632, draft PR #53) by D0388's draft-PR route. Both discriminators were read off that run: the
## two separate OS processes agreed bit-identically (first mismatch at -1) and the seed+1 control
## diverged at the very first checkpoint. Coverage did NOT move again -- `jumps=833 mantles=0 stepups=0
## digs=345 corner_ok=5 corner_unconsented=0`, identical to the D0626/D0627 pin: the replay's path is
## unchanged while the world under it differs. CI's dump equalled the local macOS dump ELEMENTWISE at
## **200 of 200**, compared before splicing, never captured from here; the spliced array then passed a
## local macOS run at all 200 checkpoints. The same CI run showed two sibling pins the same commits
## moved, re-pinned in this commit: `test_tree_pass`'s colours (P036's palette doubles them) and
## `test_rock_laminae`'s per-cell dip bound (P044's table sine quantizes it to ~0.148 m).
## **This note is the newest; the ones below it are older.**
##
## **RE-PINNED 2026-09-11 for D0626/D0627**, the tree footing and the six crowns, from CI's pinned Linux
## build (run 34665748233, draft PR #52) by D0388's draft-PR route. Both write terrain cells, so this is a
## world-GENERATION change and the array moves from checkpoint **0**. Both discriminators were read off
## that run: the two separate OS processes agreed bit-identically (first mismatch at -1) and the seed+1
## control diverged at the very first checkpoint. CI's dump equalled the local macOS dump ELEMENTWISE at
## **200 of 200**, compared before splicing, never captured from here.
## Coverage did NOT move -- `jumps=833 mantles=0 stepups=0 digs=345 corner_ok=5 corner_unconsented=0`,
## identical to the D0402 pin. That is the expected result and it bounds the change: the replay's body
## never touches a tree in 20,000 ticks, so the trajectory is unchanged while the grid hash differs.
##
## **RE-PINNED 2026-09-05 for D0402**, the three generation forks (the pad halved, `cave.deep_at_m` 140,
## aquifers from 48 m), from CI's pinned Linux build (PR #51, run 33953607297) by D0388's draft-PR route.
## A data change to the boot site is a world-GENERATION change, so the array moves from checkpoint **0**.
## Both discriminators were read off that run: the two separate OS processes agreed bit-identically
## (first mismatch at −1) and the seed+1 control diverged at the very first checkpoint. Coverage MOVED,
## as a different world must move a path through it -- `jumps=833 mantles=0 stepups=0 digs=345
## corner_ok=5 corner_unconsented=0` against `858/360/6` -- and the CI array equalled the local macOS
## dump ELEMENTWISE at 200 of 200 with the same tuple, compared before splicing, never captured from here.
## That run was 124 passed / 2 failed of 126: this suite and `test_carve_fraction`, whose ratchet was
## re-pinned to the new measured density in the same commit (0.0561 → 0.0781 non-shelf).
##

const HASHES: PackedStringArray = [
	"3240943516", "1595632732", "910895596", "3355612080", "1965421030", "3475851558", "261776292", "2080001462", "2889761031", "4279534207",
	"4008953632", "2403405606", "2097190355", "2874477349", "2641290633", "2476956761", "3193365184", "3544916391", "4137422152", "4001733843",
	"2823728681", "1057469608", "706156932", "1804114759", "2920052297", "2468547930", "1731687592", "404708248", "3623583562", "3821762034",
	"2534299587", "2079473648", "3197344084", "3513638631", "4141499090", "1663389368", "1091196572", "1951877192", "2882755704", "2344673131",
	"2031048071", "3406368251", "300670423", "2884116319", "2150589942", "570679260", "791309254", "1853782091", "845423754", "560139487",
	"1941299065", "5295785", "2831917002", "886523744", "2334034533", "103775894", "3222171213", "4285808298", "4277603566", "1658120529",
	"341127952", "1755676593", "1503460896", "1581270227", "1641337387", "1736093109", "1648427760", "772497652", "1271307743", "3107705421",
	"3829988918", "3811418381", "1237819036", "1721507480", "160652762", "3513617800", "2461879910", "2646545404", "4245218869", "3946114710",
	"1007006357", "1888933804", "3881962362", "500190949", "2029877559", "910274046", "3563213656", "2069080913", "1724591036", "1567614469",
	"1251344242", "3969505296", "2813639850", "2637708960", "2532953564", "1451042118", "2145321879", "2235366920", "6905239", "3084931051",
	"1586858643", "3327687963", "761850749", "1840303902", "2666009530", "3673054536", "949571569", "2892216186", "296186402", "2745571783",
	"1432641037", "2478330017", "2569716070", "1119100735", "2166776103", "1855514756", "3561704430", "2857317560", "4193841140", "1063297797",
	"955713448", "280948235", "2638738034", "1864513143", "2724559077", "4088735699", "4258422083", "223070345", "2434682884", "2500500619",
	"3387552091", "1490031249", "3165406232", "2592094655", "1300171008", "1938415300", "4236598366", "2097850942", "2087932396", "2489666486",
	"3549681839", "2673781151", "773894693", "868138385", "3441124866", "1643053507", "1826215966", "1842134135", "3370536404", "128492845",
	"1813496861", "3928822228", "480939375", "1442511375", "2658561413", "1013004672", "4206772286", "672335026", "2630336499", "1940841282",
	"4231029332", "1004464259", "3626808716", "355628563", "1254573776", "1034975467", "2187259563", "4290693663", "1320151011", "3958891754",
	"27216529", "1295938281", "2055052559", "757100848", "2285930689", "2614029657", "628817788", "283596856", "105456238", "2749424581",
	"2372631481", "194885908", "3102582566", "1864923125", "3289681524", "2459308333", "2494545204", "476301998", "3897043826", "3239546065",
	"2903980823", "108860887", "4111318095", "1888562853", "2159543413", "689123909", "1871293637", "1317303852", "1706908739", "524861913",
]
