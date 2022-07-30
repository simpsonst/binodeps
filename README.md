# Purpose

Binodeps is a set of GNU Make rules for building C and C++ programs in such a way that dependencies are automatically generated during compilation.
Other software might expect Binodeps to be installed as part of its build environment.

Defaults assume Linux, GNU Make and GCC.
Other environments might be possible.


# Installation

To install in `/usr/local`:

```
make
sudo make install
```

Override `PREFIX` to install elsewhere.
For example:

```
make
make PREFIX=$HOME/.local install
```

Note, if you do this, calls to `make` must include the directory in the search path.
For example:

```
make -I$HOME/.local/include
```

# Use

If you're just installing some other software that uses Binodeps, you don't have to do anything special, except ensure that the installed `binodeps.mk` can be found by `make`.
The default installation places it in `/usr/local/include`, which is a standard location for `make` to search.
If you've installed it somewhere else, you need to add that location with `-I`.
For convenience, you can set it with the environment variable `MAKEFLAGS`, e.g.:

```
export MAKEFLAGS="-I$HOME/.local/include"
```

You could also emulate a colon-separated `MAKEPATH` environment variable like this:

```
## in ~/.bash_aliases
function make () {
    local seq="$MAKEPATH"
    local args=()
    local hdr
    while hdr="${seq%%:*}"
          [ "$hdr" ] ; do
        args+=("-I$hdr")
        seq="${seq#"$hdr"}"
        seq="${seq#:}"
    done
    $(which make) "${args[@]}" "$@"
}
```

…or do an equivalent in `/usr/local/bin`.
However, either way, `sudo` won't pick it up.

If you're developing a C or C++ program or library, and want Binodeps to simplify the maintenance of dependencies, there are [detailed instructions](https://scc-forge.lancaster.ac.uk/open/simpsons/software/pkg-binodeps).
