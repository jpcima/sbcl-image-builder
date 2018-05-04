# sbcl-image-builder
Lisp image build for SBCL

This is my build system to create custom SBCL executables preloaded with a collection of Quicklisp libraries.
It will compile the libraries and embed them in a SBCL executable which is very fast to load.

The build script `sbcl-core.lisp` provides a basic set of commonly used utility libraries.
This can be edited or used as a template to create more specific Lisp environments.

## Requirements

- SBCL in the program path
- a copy of ASDF in `~/.common-lisp/asdf.lisp`
- a Quicklisp installation in `~/.common-lisp/quicklisp/`

If you prefer to use different paths than these, edit them in the build script.

## Build

Run `make`. Install with `make install`.

## Customization

Find relevant sections in the build script and list systems you want embedded, and add your custom initialization code.

- `LOAD-SYSTEM NAME` loads a system and adds it.
- `USE-SYSTEM NAME &REST PACKAGES` loads a system, adds it, and imports package symbols into `CL-USER`.
If no package was named, imports the package with the same name as the system.
- `INITIALIZE &BODY BODY` adds code to run at initialization.

## Usage in Emacs

Make your Lisp image known to SLIME, and optionally make it the default.

As a benefit of constructing an image with `USE-SYSTEM`, SLIME will automatically recognize the packages and their symbols when used in any context.

```
(setq slime-lisp-implementations
      '((sbcl ("sbcl"))
        (sbcl-core ("sbcl-core")))
      slime-default-lisp 'sbcl-core)
```
