# Volume granularity: global vs per-project

Type: grilling
Status: open

## Question

`claude-toolbox` today is invoked from any `$PWD` and shares one host `~/.claude` across every project. Once settings move to a container-only volume, should there still be one global volume shared across all projects run through `claude-toolbox`, or one volume per project/repo? This affects whether switching projects carries over plugin state, conversation history, and project memory, or isolates them.
