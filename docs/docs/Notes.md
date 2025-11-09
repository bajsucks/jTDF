# Other information

## Contributing

You can contribute to the project or this documentation by opening a github pull request

## Feedback and support

If you want to share your feedback, suggestions or need help with usage of the framework, you can do it on:

- Devforum page

- <a href="https://discord.gg/zNyyVCUuS8">Discord community server</a>

## Path creation

Paths are a series of attachments that enemies follow, creating a linear path with a clear beginning and end.

For an attachment to be considered part of a path, it has to have those properties:

- `EnemyPath` tag
- `PathID` attribute containing a number that will be this attachment's order on the path. It is recommended that all PathIDs are sequential, e.g. `1` `2` `3`, but should work even when they are non-sequential, e.g. `10` `15` `16` `23`.
- `pathLabel` attribute containing the name of the path this attachment belongs to

## Radii throttle

When a radius does not have enemies close, it will slow down it's update rate to once every 5 frames.

However, when a new enemy is created, radius will instantly wake up from the throttle. That is to ensure radii work correctly when they contain an enemy spawn location within themselves.

If you wish to manually wake a radius up from throttle, use the [.Update signal](../jTDF/#update).