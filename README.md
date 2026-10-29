# Godor animation action import

Imports individual skeleton animation clip files and generates animation resources.

Developed on: Godot 4.7

# What is it for

The default workflow for animated game characters is to store all animation clips in one exported file, along with the skeleton and mesh. This is not ideal workflow and it's weird most engines/plugins don't allow to export separate animation files, not dependent on the mesh or skeleton.

This plugin aims to change that, now animation clips can be exported and imported separately, allowing for more flexible workflow.

# Usage

Drop `addons` folder into root folder of your Godot project. Enable the addon.

Use Blender addon to export animation clips: https://github.com/Rytelier/Blender-action-export-to-file

One `.animt` files are imported into your Godot project, animation clip `.res` files will be generated in same folder. You can adjust settings of the `.animt` files in the `Import` tab.

`Skeleton Path Override` will change the skeleton node path for the animation resource's tracks, relative to `AnimationMixer`'s `Root Node` parameter. By default (unchecked) the path is `[parent node name]/Skeleton3D`.

Leave setting checked and `Custom Skeleton Path` for direct bone path (when `Root Node` is set to the skeleton).

`Optimize` and its settings below will remove reduntant keyframes.

When `Custom File Folder` is set, resource files will be generated there instead of the original import location.

## Custom tracks

You can add custom tracks (like function call tracks) to the generated animation files and they will be preserved when animation is reimported. Changes to the imported tracks will be overriden.