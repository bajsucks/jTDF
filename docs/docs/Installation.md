# Installation

You can download jTDF from the following places:

- [Github releases](https://github.com/bajsucks/jTDF/releases)

It is recommended to parent jTDF to `ReplicatedStorage` so the client is able to import jTDF types, although it will work correctly when parented anywhere else too.

When required on server, jTDF will create a folder `jTDF_Actors` in `ServerScriptService`. This folder is used to store actors for parallelization; Do not touch it!

jTDF module has tag `_JTDFMODULE`, which is used in actors to find it's location. Do not remove it! If you got the module from source, do not forget to add that tag!