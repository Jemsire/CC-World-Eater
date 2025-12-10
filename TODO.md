List of things i want to get to at some point.
These will change as the project goes on and is more of a notes section for myself than anything.
Most other ideas from contributers and the community will be inside the issues area.

List:
- add monitor prompts for update tasks and display confirms and warnings there. Allow major update to be prompted on there. Basically clear screen and display a progress bar and info there so you know when an update or action has actually triggered and if its working. Good way to visualize errors as well. Will need a bit of a rework on the monitor system.
- add a manual update to the turtles of placed next to the drive. This currently does not work as intitialize task can break and the turtle can trigger an update without being initialized. Will look at redoing the order or checks at some other point. Basically when turtle turns on, if next to disk drive, ask hub for update and update before intializing hopefully without a boot loop. Maybe actually use the UPDATED flag file that does not really do much currently.



MAJOR:
- Fix movement logic to not use paths anymore or only use paths for specific state changes.
- Add a pathfinding system where it justs moves using air block checks and pathfinds around objects if in waiting area.
- When below/in mining area it should just mine through blocks to pathfind unless its a computer AKA friend.
- Current issue is the commands im trying to give in world eater during pairing are failing due to paths not being a thing for the new logic i made.
- Make mine area check just a simple in area not in a specific path and same for parked but parked checks the lanes.
- Add hard coded locations for fuel and empty chests so those paths can be removed.
- Possibly some form of road system where they drive a specific path when doing things like going to fuel and empty and then a different path when coming up from the mines so they dont collide but pathfinding/move states already check of occluded by a friend so it does not matter much.
- Pairing works good but we could possibly send the chunk when the miner finishes fuel and move up then over instead of out then zigzag(probably path related issue).
- Could keep paths if we make them points that must be path found to so its only turns that need fixed in code.