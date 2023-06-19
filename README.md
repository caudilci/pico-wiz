# Pico-Wiz

This is a repository to track the progress of development on a magical roguelike ~~heavily inspired by~~ ripped off from [Rift Wizard](https://store.steampowered.com/app/1271280/Rift_Wizard/)

This is the first game I plan on completing in the pico-8 engine, with the end goal of making a handfull of games that I'd personally enjoy playing on linux handhelds such as the Miyoo Mini


### TODO
- ~~stop enemy healthbar from moving on collision~~
- ~~stop enemy from showing collision with other enemies~~
- ~~switch menu to utilize vertical and horizontal indices --> required for spell upgrading~~
- ~~spell unlocking~~
- ~~deep copy function~~
- ~~fix spell menu bug -> can't select spell when menu is opened for the first time~~
- ~~add items as their own object like spells~~
- ~~fix spell buying bug (only buys spells closest to top of list)~~
- spell cast function -- In Progress
- ~~turn counter/floor counter UI~~
- ~~spell upgrades~~
- spell cooldown (for enemies) -- In Progress
- enemy spells -- In Progress
- world gen -- In Progress
- ~~death screen/handling~~
- ~~title screen~~
- adjust spell menu highlighting remove player location from list
- auto pickup items on level complete -> maybe replacing spell cast functionality
- auto target ~~nearest~~ enemy on cast
- polish

### Stretch Goals
- item/upgrade shop?
- mob/enemy encyclopedia
- mob typing --> rock>fire fire>wood etc
- status effects --> health bar denotes status effect for enemies, not sure about player
    - poison
    - frenzy
    - burn
    - teleportitis
- summons/allied mobs
- enough spells to scroll menu
- usable vs key items?
- final boss?

### Known Bugs
- ball spells play cast animation on walls
- some visible tiles in cast rage are inaccessible
- sometimes animation will be delayed when killing last enemy on floor