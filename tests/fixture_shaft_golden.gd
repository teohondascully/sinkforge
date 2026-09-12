extends RefCounted
## THE SHAFT-REPLAY GOLDEN: the 200 checkpoint hashes `tests/test_shaft_replay_determinism.gd` pins, and
## the note of every re-pin since the array moved here (2026-09-05, at that file's 400-line cap). The
## rules are in the suite's header and are not repeated: captured from CI's pinned Linux build, never from
## a developer machine; a move from checkpoint 0 is a world change; both discriminators read off the run.
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
## **This note is the newest; the ones below it are older.**
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
	"2133963517", "3286439518", "914007882", "926729499", "3299045984", "1134061242", "1404442808", "37643762", "2463234813", "1842326864",
	"2923270384", "2577364858", "3347906801", "2904444910", "2863087521", "3582321210", "1838513277", "1979164182", "3128947521", "1393267084",
	"3389517132", "1379050741", "1051635921", "2726801236", "2172856079", "110872160", "1760045991", "1323625482", "1985528892", "4210227847",
	"2576463053", "141131975", "3613392607", "1268659404", "3115563515", "2562165972", "1630341884", "4046267029", "915918299", "819512876",
	"3354787784", "4192612914", "1823103659", "288513603", "835955537", "238510583", "3047497688", "2540325564", "3624238811", "201025138",
	"63997557", "600398757", "3684585702", "1480777495", "2003993276", "1419902221", "1247732644", "2509514788", "2164496232", "3361578581",
	"843973556", "3597851134", "4294837584", "3923446292", "3503868883", "3613635037", "2635350488", "1246596672", "902091709", "2698729648",
	"1407431013", "2658952700", "327942987", "611031406", "229858688", "886583470", "3114947423", "2254755524", "1305318408", "3774552760",
	"1710080984", "56396463", "1700206150", "4033077361", "3414484803", "3936971210", "2475216292", "268110301", "2140098382", "3794775579",
	"2973882056", "3818802918", "3506749952", "3827988089", "371060021", "3322687967", "1862576928", "1137378769", "350024137", "2360170377",
	"4228285139", "3562399967", "88359876", "2232844752", "445396820", "4049302904", "2593493658", "666457417", "186167859", "1903203128",
	"248732400", "266574417", "2779592755", "575869076", "1785807413", "4228327193", "1639549571", "935162701", "2271686281", "3436110234",
	"3029229470", "3344126273", "775301192", "37070605", "2590895973", "3955072595", "4124758979", "89407241", "2301019780", "2366837515",
	"1906874781", "654898515", "1504501774", "931190197", "3934233846", "277510842", "2575693908", "436946484", "427027938", "828762028",
	"1888777381", "3655021086", "2706727204", "316776848", "1936161217", "3882824002", "2764163635", "2825151068", "507508857", "4188186002",
	"3910625076", "994040619", "34311697", "3531520924", "2826036773", "1180480032", "79280350", "839810386", "2717297226", "2868593729",
	"2735392043", "753432088", "3101112651", "4124899794", "2229896013", "4128571526", "3470775057", "3756671365", "2649013009", "992786456",
	"325041342", "401141526", "2062243772", "4242059165", "859549422", "2520255878", "3898817257", "2025366182", "1066821468", "2832197363",
	"2334912999", "2238258306", "710840383", "857947639", "963030061", "641828654", "1072121470", "2228525688", "2685802082", "3722669501",
	"3364341123", "3722253431", "2659355119", "1388931838", "726062206", "3114431166", "2168340979", "2482071871", "326776005", "2079426904",
]
