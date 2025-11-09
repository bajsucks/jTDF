Welcome to documentation for Baj's Tower Defense Framework!
## Project Description
Ba<b>j</b>'s <b>T</b>ower <b>D</b>efense <b>F</b>ramework (jTDF) is an open source framework, designed to make creation of Tower Defense games on Roblox easier.

jTDF handles:

- Towers: stats, placement, upgrades
- Enemies: health, speed, death
- Enemy detection: easily create enemy detection radii with no concern for performance
- Paths
- API endpoints


what jTDF does NOT handle:

- Game logic
- Rendering
- Anything client side

## Why choose us?

### Ease of use

When trying to learn new frameworks, beginner developers often get confused, frustrated, and don't understand how to create exactly what they want.

jTDF solves that by providing a comprehensible documentation and keeping functions clean and understandable.

### Performance

jTDF optimizes all internal heavy tasks with [parallel luau](https://create.roblox.com/docs/scripting/multithreading) without restricting developer freedom.

Math and checks happen on server, rendering and animation happen on client.

### Customization

All functions and data structures are built in a way which allows for their dynamic modification. jTDF assumes nothing about your game, except that it's a tower defense. You are free to do everything in your own way.

### Security

jTDF is a server tool, it does not handle user input.

That being said, important functions are secured with `t` module type checking.

In API reference you will see a note under functions that use `t`.

## Games using jTDF

If your game uses jTDF and you want to be added to this page, you can dm me in Discord ([@bajsucks](https://discord.com/users/749693393185276024)) or ping me on the [jTDF community server](https://discord.gg/zNyyVCUuS8).