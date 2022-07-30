## Copyright (c) 2009-2022, Lancaster University
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are
## met:
##
##  * Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
##
##  * Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the
##    distribution.
##
##  * Neither the name of the copyright holder nor the names of its
##    contributors may be used to endorse or promote products derived
##    from this software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
## "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
## LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
## A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
## OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
## SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
## LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
## DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
## THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
## (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##
## Contributors:
##    Steven Simpson <https://github.com/simpsonst>

## Hacks to get macros containing characters special to Make
binodeps_blank:=
binodeps_space:=$(binodeps_blank) $(binodeps_blank)
binodeps_comma=,

## Escape spaces in the current directory.  TODO: Should we escape
## backslash too?
BINODEPS_CURDIR:=$(subst $(binodeps_space),\$(binodeps_space),$(CURDIR)/)

## Provide a version of $(abspath) that can cope with spaces in the
## current directory.
BINODEPS_ABSPATH=$(foreach f,$1,$(if $(patsubst /%,,$f),$(BINODEPS_CURDIR)$f,$f))


### Directory structure

## Default installation locations

PREFIX ?= /usr/local
LIBDIR ?= $(PREFIX)/lib
SHAREDIR ?= $(PREFIX)/share
LIBEXECDIR ?= $(PREFIX)/libexec
BINDIR ?= $(PREFIX)/bin
SBINDIR ?= $(PREFIX)/sbin
INCDIR ?= $(PREFIX)/include
APPDIR_RISCOS ?= $(PREFIX)/apps
ZIPDIR_RISCOS ?= $(APPDIR_RISCOS)

## These define the default directory structure of the user's project.
BINODEPS_DOCDIR ?= docs
BINODEPS_SRCDIR ?= src/obj
BINODEPS_SCRIPTDIR ?= src/scripts
BINODEPS_SHAREDIR ?= src/share
BINODEPS_SHAREDIR_RISCOS ?= src/riscos
BINODEPS_TMPDIR ?= tmp
BINODEPS_OUTDIR ?= out
BINODEPS_OBJDIR ?= $(BINODEPS_TMPDIR)/obj
BINODEPS_SRCDIR_DYN ?= $(BINODEPS_OBJDIR)
BINODEPS_BINDIR ?= $(BINODEPS_OUTDIR)
BINODEPS_LIBDIR ?= $(BINODEPS_OUTDIR)
BINODEPS_HDRDIR ?= $(BINODEPS_OUTDIR)/include
BINODEPS_OUTDIR_RISCOS ?= $(BINODEPS_OUTDIR)/riscos
BINODEPS_ZIPDIR_RISCOS ?= $(BINODEPS_OUTDIR)


### Simple commands

CMP ?= cmp
FIND ?= find
AR ?= ar
RANLIB ?= ranlib
CD ?= cd
CP ?= cp
MV ?= mv
CAT ?= cat
PRINTF ?= printf
ZIP ?= zip
ZIPCMP ?= zipcmp
RISCOS_ZIP ?= $(ZIP)
ELF2AIF ?= elf2aif
TAR ?= tar
TR ?= tr
INSTALL ?= install
CMHG ?= cmunge
OS_UNAME := $(shell uname)
PAR ?= par
TPUT ?= tput
TPUT_COLS ?= $(TPUT)
ECHO ?= echo
WC ?= wc
LN ?= ln
LDCONFIG ?= ldconfig
TOUCH ?= touch

BINODEPS_REAL_INCLUDE := $(dir $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST)))
BINODEPS_REAL_HOME1=$(BINODEPS_REAL_INCLUDE:%/include/=%)
BINODEPS_REAL_HOME=$(BINODEPS_REAL_HOME1:include/=.)


### Complex commands

## Make a directory and its parents.
MKDIR ?= mkdir -p

## A command to pretty-print words
TERMWIDTH ?= $(shell $(TPUT_COLS) cols 2> /dev/null || $(ECHO) 80)
FOLD ?= fmt -t -w $(TERMWIDTH)

ifeq ($OS_UNAME,Darwin)
PRINTLIST=$(PRINTF) $1'%s\n' $2 $3
else
PRINTLIST=$(PRINTF) $1'%s\n' $2 $3 \
  | $(PAR) 'rTbgqR0E' 'B=.,?_A_a Q=_s>|' \
    w$(TERMWIDTH) p$(shell $(PRINTF) $1 $2 \
  | $(WC) -m)
endif

## A command to selectively copy a file if its contents has changed -
## $1 is the source; $2 is the destination; $3 is a label to print if
## the copy occurs.
CPCMP=$(CMP) -s '$1' '$2' || \
  ( $(CP) '$1' '$2' && $(PRINTF) '[Changed]: %s\n' '$3' )

## These processes remove headers with absolute paths from dependency
## files.  If this seems to be causing problems, just use $(CAT) as a
## workaround.  's/\B\/.*\.h//g' is too simple. "/a/b.h foo.h" will be
## deleted, rather than leaving "foo.h".
STRIP_SYSTEM_RULES ?= sed -e 's/ \/[^ ]*//g'


## Calculate the longest label.
SUBMODEL_LABEL_LENGTHS= \
$(sort $(foreach T,$(SUBMODELS_SORTED),\
	 $(shell $(PRINTF) '%010x' \
	   $(shell $(PRINTF) '%s' '$(SUBMODEL_LABEL@$T)' | $(WC) -m))))
SUBMODEL_LABEL_MAXLEN= \
  $(shell $(PRINTF) '%d\n' \
    0x$(word $(words $(SUBMODEL_LABEL_LENGTHS)),$(SUBMODEL_LABEL_LENGTHS)))


### Translator switches

## Default switches for GCC (and Clang) to generate useful
## dependencies - We select only user headers (not system), we list
## each dependency in a dummy rule to deal with deletions, and targets
## and the file to write the rules in are the first and second
## arguments.
DEPARGS ?= -MMD -MP -MT '$1' -MF '$2'
DEPARGS.c ?= $(DEPARGS)
DEPARGS.cc ?= $(DEPARGS)


## Default switches for generating source from RISC OS module
## descriptions
CMHGFLAGS += -tgcc -32bit



### Suffixes that require special treatment

## These are the suffixes that we have to swap with a file's leafname
## to get the right order for RISC OS.
RISCOS_SUFFIXES += c cc h hh s Hdr cmhg

## Files with these suffixes, when copied, have a #line prefixed to
## them.  REDUNDANT: Only used by COPIED_SUFFIXES, which is redundant.
# CPP_SUFFIXES += c cc h hh S

## Copies of files with these suffixes are intermediates that should
## not automatically be deleted after use.  REDUNDANT: These are only
## used to declare the copied files as precious, and that is now done
## in the *PP_COPY_RULE macros.
# COPIED_SUFFIXES += $(CPP_SUFFIXES)
# COPIED_SUFFIXES += s

### Built-in submodels

## Binaries in the default submodel use the internal label 'default',
## no suffix, and are built from .o files.  Additionally, for
## compatibility with pre-submodel-specific users, we generate the
## list of default-submodel binaries from the unsuffixed variables.
SUBMODELS += default
SUBMODEL_LABEL@default=
SUBMODEL_SFX@default=
SUBMODEL_LIBSFX@default=.a
SUBMODEL_OBJSFX@default ?= .o
libraries@default += $(libraries)
test_libraries@default += $(test_libraries)
hidden_libraries@default += $(hidden_libraries)
binaries.c@default += $(binaries.c)
hidden_binaries.c@default += $(hidden_binaries.c)
admin_binaries.c@default += $(admin_binaries.c)
test_binaries.c@default += $(test_binaries.c)
binaries.cc@default += $(binaries.cc)
hidden_binaries.cc@default += $(hidden_binaries.cc)
admin_binaries.cc@default += $(admin_binaries.cc)
test_binaries.cc@default += $(test_binaries.cc)

## For pre-submodel-specific users, these unsuffixed variables just
## default to the default-submodel ones.
EXPORT_BINARIES ?= $(EXPORT_BINARIES@default)
HIDDEN_BINARIES ?= $(HIDDEN_BINARIES@default)
ADMIN_BINARIES ?= $(ADMIN_BINARIES@default)
TEST_BINARIES ?= $(TEST_BINARIES@default)
BINARIES ?= $(BINARIES@default)

## RISC OS modules use the internal submodel label 'riscos-rm', the
## suffix '.rm' on the binaries, and are built from .mo files.
SUBMODELS += riscos-rm
SUBMODEL_SFX@riscos-rm=.rm
SUBMODEL_OBJSFX@riscos-rm ?= .mo
SUBMODEL_LABEL@riscos-rm=RISC OS RM
CPPFLAGS@riscos-rm += -mlibscl -mmodule -mfloat-abi=$(FPABI@riscos-rm)
ASFLAGS@riscos-rm += -mfloat-abi=$(FPABI@riscos-rm)
FPABI@riscos-rm ?= hard



### Functions for RISC OS filenames

riscos_file=$(foreach S,$(RISCOS_SUFFIXES),$(join $(foreach F,$(dir $(filter %.$S,$2)),$1$(patsubst ./,,$F)$S/),$(patsubst %.$S,%$(binodeps_comma)fff,$(notdir $(filter %.$S,$2)))))
riscos_src=$(call riscos_file,Source/,$1)
riscos_hdr=$(call riscos_file,Library/,$1)
riscos_lib=$(foreach F,$1,Library/o/$($F_libname),ffd)
riscos_bin=$(foreach F,$1,Library/$F,ff8)



### Some computed lists

## Get a list of directories in source, so we can generate non-trivial
## RISC OS rules for each one.
#FIXED_SOURCE_DIRS:=$(if $(wildcard $(BINODEPS_SRCDIR)),$(shell $(FIND) $(BINODEPS_SRCDIR) -type d -printf '%P\n'))
FIXED_SOURCE_DIRS:=$(if $(wildcard $(BINODEPS_SRCDIR)),$(patsubst $(BINODEPS_SRCDIR:%/=%)/%,%,$(shell $(FIND) $(BINODEPS_SRCDIR) -type d)))
SOURCE_DIRS:=$(sort $(patsubst %/,%,$(filter-out ./,$(dir $(headers)))) $(FIXED_SOURCE_DIRS))

## Get the full list of RISC OS applications.
RISCOS_APPS=$(sort $(foreach zip,$(riscos_zips),$($(zip)_apps)))

## Create a list of all object-file suffixes.  TODO: Redundant?
OBJECT_TYPES += $(foreach T,$(SUBMODELS),$(SUBMODEL_OBJS@$T))

## Get a union of all objects.  This list is used to mark some
## intermediates as precious, and to trigger copying of static header
## files.
ALL_OBJECTS=$(sort $(foreach T,$(SUBMODELS),$(ALL_OBJECTS@$T)))

## Find all the directories that contain headers to be installed.
## Headers that are not listed under directories yield "./".
# HEADER_DIRS=$(sort $(dir $(headers)))

## Rename the headers so that those not listed under directories are
## prefixed with "./", so that we can match them.  For example
## "foo/bar.h" remains unchanged, but "bar.h" becomes "./bar.h".
# ALT_HEADERS=$(join $(dir $(headers)),$(notdir $(headers)))

## Get the list of headers under a directory.  Use "./" for the top
## level.  Use "foo/" for everything else.
# HDRSUNDIR=$(patsubst $1%,%,$(filter $1%,$(ALT_HEADERS)))

## Get the list of headers that are direct descendants of a directory.
## We take the list of headers *under* the directory, and then remove
## only those that have no directory component.
# HDRSINDIR=$(filter $(notdir $(call HDRSUNDIR,$1)),$(call HDRSUNDIR,$1))



## Get the list of static header files to be copied according to an
## order-only rule in preparation for any translation.
#HEADER_LIST:=$(if $(wildcard $(BINODEPS_SRCDIR)),$(shell $(FIND) $(BINODEPS_SRCDIR) \( -false -o -name '*.h' -o -name '*.hh' \) -printf '%P\n'))
HEADER_LIST:=$(if $(wildcard $(BINODEPS_SRCDIR)),$(patsubst $(BINODEPS_SRCDIR:%/=%)/%,%,$(shell $(FIND) $(BINODEPS_SRCDIR) \( -false -o -name '*.h' -o -name '*.hh' \))))



## Find all the directories that contain datafiles to be installed.
## Datafiles that are not listed under directories yield "./".
# DATAFILE_DIRS=$(sort $(dir $(datafiles)))

## Rename the datafiles so that those not listed under directories are
## prefixed with "./", so that we can match them.  For example
## "foo/bar.h" remains unchanged, but "bar.h" becomes "./bar.h".
# ALT_DATAFILES=$(join $(dir $(datafiles)),$(notdir $(datafiles)))

## Get the list of datafiles under a directory.  Use "./" for the top
## level.  Use "foo/" for everything else.
# DFSUNDIR=$(patsubst $1%,%,$(filter $1%,$(ALT_DATAFILES)))

## Get the list of datafiles that are direct descendants of a directory.
## We take the list of datafiles *under* the directory, and then remove
## only those that have no directory component.
# DFSINDIR=$(filter $(notdir $(call DFSUNDIR,$1)),$(call DFSUNDIR,$1))

## Find all the directories that contain the files listed in $1.
## Those in the top level will yield "./" as the directory.
DIRS=$(sort $(dir $1))

## Rename listed files so that those not listed under directories are
## prefixed with "./", so that we can match them.  For example
## "foo/bar.h" remains unchanged, but "bar.h" becomes "./bar.h".
ALTFILES=$(join $(dir $1),$(notdir $1))

## Get a subset of a list of files $2 under a directory $1.  Use "./"
## for the top level.  Use "foo/" for everything else.
UNDIR=$(patsubst $1%,%,$(filter $1%,$(call ALTFILES,$2)))

## Get the list of files that are direct descendants of a directory.
## We take the list of files *under* the directory, and then remove
## only those that have no directory component.
INDIR=$(filter $(notdir $(call UNDIR,$1,$2)),$(call UNDIR,$1,$2))

## Get a list of all submodels with duplicates removed.
SUBMODELS_SORTED=$(sort $(SUBMODELS))


### Templates for generating definitions and rules

define DEFS4SUBMODELS
SUBMODEL_SFX@$1 ?= .$1
SUBMODEL_LIBSFX@$1 ?= .a.$1
SUBMODEL_LIBPFX@$1 ?= lib
SUBMODEL_SLIBPFX@$1 ?= $$(SUBMODEL_LIBPFX@$1)
SUBMODEL_SLIBSFX@$1 ?= $$(SUBMODEL_OBJSFX@$1:.%=.s%)
SUBMODEL_OBJSFX@$1 ?= $1
SUBMODEL_SOBJSFX@$1 ?= $$(SUBMODEL_OBJSFX@$1:.%=.l%)
SUBMODEL_LABEL@$1 ?= $1
SUBMODEL_LABEL_IN@$1 ?= \
  $$(if $$(SUBMODEL_LABEL@$1),$(binodeps_space)($$(SUBMODEL_LABEL@$1)))

AR@$1 ?= $$(AR)
RANLIB@$1 ?= $$(RANLIB)
AS@$1 ?= $$(AS)
CC@$1 ?= $$(CC)
CPP@$1 ?= $$(CPP)
CXX@$1 ?= $$(CXX)

DEPARGS.c@$1 ?= $$(DEPARGS.c)
DEPARGS.cc@$1 ?= $$(DEPARGS.cc)

TARGET_ARCH@$1 += $$(TARGET_ARCH)
ASFLAGS@$1 += $$(ASFLAGS)
CFLAGS@$1 += $$(CFLAGS)
CPPFLAGS@$1 += $$(CPPFLAGS)
CXXFLAGS@$1 += $$(CXXFLAGS)
LDFLAGS@$1 += $$(LDFLAGS)

## Compile from source files.
COMPILEFLAGS.S@$1=$$(CPPFLAGS@$1)
COMPILEFLAGS.s@$1=$$(ASFLAGS@$1)
COMPILEFLAGS.c@$1=$$(CFLAGS@$1) $$(CPPFLAGS@$1) $$(TARGET_ARCH@$1)
COMPILEFLAGS.cc@$1=$$(CXXFLAGS@$1) $$(CPPFLAGS@$1) $$(TARGET_ARCH@$1)
COMPILE.S@$1 ?= $$(CPP@$1) $$(COMPILEFLAGS.S@$1)
COMPILE.s@$1 ?= $$(AS@$1) $$(COMPILEFLAGS.s@$1)
COMPILE.c@$1 ?= $$(CC@$1) $$(COMPILEFLAGS.c@$1) -c
COMPILE.cc@$1 ?= $$(CXX@$1) $$(COMPILEFLAGS.cc@$1) -c

SHLIBOPTS@$1 ?= -fPIC
SHLIBOPTS.c@$1 ?= $$(SHLIBOPTS@$1)
SHLIBOPTS.cc@$1 ?= $$(SHLIBOPTS@$1)

## Link executables.
LINK.c@$1 ?= $$(CC@$1) $$(CFLAGS@$1) $$(CPPFLAGS@$1) \
$$(LDFLAGS@$1) $$(TARGET_ARCH@$1)
LINK.cc@$1 ?= $$(CXX@$1) $$(CXXFLAGS@$1) $$(CPPFLAGS@$1) \
$$(LDFLAGS@$1) $$(TARGET_ARCH@$1)


## Link shared libraries.  $1 is the model, $2 is the soname, $3 is
## the list of modules.
SAR@$1 ?= $$(CC@$1) $$(LDFLAGS@$1) $$(TARGET_ARCH@$1) \
-shared '-Wl,-soname,$$2' -o '$$1' $$3

## Get a canonical list of all libraries and binaries, whether
## exported or not.
LIBRARIES@$1=$$(sort $$(test_libraries@$1) \
		     $$(hidden_libraries@$1) \
		     $$(libraries@$1))
BINARIES.c@$1=$$(sort $$(test_binaries.c@$1) \
		      $$(binaries.c@$1) \
		      $$(admin_binaries.c@$1) \
		      $$(hidden_binaries.c@$1))
BINARIES.cc@$1=$$(sort $$(test_binaries.cc@$1) \
		       $$(binaries.cc@$1) \
		       $$(admin_binaries.cc@$1) \
		       $$(hidden_binaries.cc@$1))

EXPORT_BINARIES@$1 += $$(binaries.c@$1)
EXPORT_BINARIES@$1 += $$(binaries.cc@$1)
HIDDEN_BINARIES@$1 += $$(hidden_binaries.c@$1)
HIDDEN_BINARIES@$1 += $$(hidden_binaries.cc@$1)
ADMIN_BINARIES@$1 += $$(admin_binaries.c@$1)
ADMIN_BINARIES@$1 += $$(admin_binaries.cc@$1)
TEST_BINARIES@$1 += $$(test_binaries.c@$1)
TEST_BINARIES@$1 += $$(test_binaries.cc@$1)

INSTALLED_BINARIES@$1 += $$(EXPORT_BINARIES@$1)
INSTALLED_BINARIES@$1 += $$(HIDDEN_BINARIES@$1)
INSTALLED_BINARIES@$1 += $$(ADMIN_BINARIES@$1)

INSTALLED_LIBRARIES@$1 += $$(hidden_libraries@$1)
INSTALLED_LIBRARIES@$1 += $$(libraries@$1)

BINARIES@$1 += $$(TEST_BINARIES@$1)
BINARIES@$1 += $$(INSTALLED_BINARIES@$1)

## List all modules.
ALL_OBJECTS@$1 += \
  $$(sort $$(foreach P,$$(BINARIES@$1),\
     $$($$P_obj) $$($$P_obj@$1)) \
     $$(foreach L,$$(LIBRARIES@$1),$$($$L_mod) $$($$L_mod@$1)))

## Per-submodel installation directories
LIBDIR@$1 ?= $$(LIBDIR)
LIBEXECDIR@$1 ?= $$(LIBEXECDIR)
BINDIR@$1 ?= $$(BINDIR)
SBINDIR@$1 ?= $$(SBINDIR)

endef

define DEPS4SUBMODELS
## When C and C++ files are compiled, ensure we keep track of which
## files were included, and use these generated rules on the next
## invocation of 'make'.
$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_OBJSFX@$1): $$(BINODEPS_SRCDIR_DYN)/%.c
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OBJDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[C] %s%s\n' '$$*' '$$(SUBMODEL_LABEL_IN@$1)'
	@$$(COMPILE.c@$1) \
	  $$(call DEPARGS.c@$1,$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_OBJSFX@$1),$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp) \
	  -o '$$@-tmp' '$$<'
	@$$(CAT) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp | \
	  $$(STRIP_SYSTEM_RULES) > $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk
	@$$(RM) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp
	@$$(MV) '$$@-tmp' '$$@'

$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_SOBJSFX@$1): $$(BINODEPS_SRCDIR_DYN)/%.c
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OBJDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[C shared] %s%s\n' '$$*' '$$(SUBMODEL_LABEL_IN@$1)'
	@$$(COMPILE.c@$1) $$(SHLIBOPTS.c@$1) \
	  $$(call DEPARGS.c@$1,$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SOBJSFX@$1),$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp) \
	  -o '$$@-tmp' '$$<'
	@$$(CAT) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp | \
	  $$(STRIP_SYSTEM_RULES) > $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk
	@$$(RM) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp
	@$$(MV) '$$@-tmp' '$$@'

$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_OBJSFX@$1): $$(BINODEPS_SRCDIR_DYN)/%.cc
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OBJDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[C++] %s%s\n' '$$*' '$$(SUBMODEL_LABEL_IN@$1)'
	@$$(COMPILE.cc@$1) \
	  $$(call DEPARGS.cc@$1,$$@,$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp) \
	  -o '$$@-tmp' '$$<'
	@$$(CAT) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp | \
	  $$(STRIP_SYSTEM_RULES) > $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk
	@$$(RM) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).static.mk-tmp
	@$$(MV) '$$@-tmp' '$$@'

$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_SOBJSFX@$1): $$(BINODEPS_SRCDIR_DYN)/%.cc
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OBJDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[C++ shared] %s%s\n' '$$*' '$$(SUBMODEL_LABEL_IN@$1)'
	@$$(COMPILE.cc@$1) $$(SHLIBOPTS.cc@$1) \
	  $$(call DEPARGS.cc@$1,$$@,$$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp) \
	  -o '$$@-tmp' '$$<'
	@$$(CAT) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp | \
	  $$(STRIP_SYSTEM_RULES) > $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk
	@$$(RM) $$(BINODEPS_OBJDIR)/$$*$$(SUBMODEL_SFX@$1).shared.mk-tmp
	@$$(MV) '$$@-tmp' '$$@'

## Unpreprocessed ASM files do not generate dependencies.
$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_OBJSFX@$1): $$(BINODEPS_SRCDIR_DYN)/%.s
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OBJDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[ASM] %s%s\n' '$$*' '$$(SUBMODEL_LABEL_IN@$1)'
	@$$(COMPILE.s@$1) -o '$$@' '$$<'

## Copy headers into place before compilation.
$$(ALL_OBJECTS@$1:%=$$(BINODEPS_OBJDIR)/%$$(SUBMODEL_OBJSFX@$1)): \
  | $$(HEADER_LIST:%=$$(BINODEPS_SRCDIR_DYN)/%)

install-binaries:: install-binaries@$1
install-hidden-binaries:: install-hidden-binaries@$1
install-admin-binaries:: install-admin-binaries@$1
install-libraries:: install-libraries@$1
install-hidden-libraries:: install-hidden-libraries@$1

## These targets now must exist, even if they eventually don't do
## anything.
install-binaries@$1::
install-hidden-binaries@$1::
install-admin-binaries@$1::
@install-libraries@$1::
install-libraries@$1:: @install-libraries@$1
	@$$(PRINTF) 'Symlinking shared libraries for %s in:\n  %s\n' \
	  '$1' '$$(LIBDIR@$1)'
	@$$(LDCONFIG) -n $$(LIBDIR@$1)

install-dev@$1:: install-libraries@$1 install-headers

install-libdir@$1::
	@$$(PRINTF) 'Installing [%s] libraries in %s:\n' '$1' '$$(LIBDIR@$1)'
	@$$(PRINTF) '\t%12s (%s)\n' \
	  $$(foreach L,$$(libraries@$1), '$$L' '$$($$L_libname@$1)')
	@$$(INSTALL) -d $$(LIBDIR@$1)

install-bindir@$1::
	@$$(PRINTF) 'Installing [%s] binaries in %s:\n' '$1' '$$(BINDIR@$1)'
	@$$(PRINTF) '\t%s\n' $$(EXPORT_BINARIES@$1:%='%')
	@$$(INSTALL) -d $$(BINDIR@$1)

install-sbindir@$1::
	@$$(PRINTF) 'Installing [%s] system binaries/scripts in %s:\n' \
	  '$1' '$$(SBINDIR@$1)'
	@$$(PRINTF) '\t%s\n' $$(ADMIN_BINARIES@$1:%='%')
	@$$(INSTALL) -d $$(SBINDIR@$1)

install-libexecdir@$1::
	@$$(PRINTF) 'Installing [%s] hidden binaries/libraries in %s:\n' \
	  '$1' '$$(LIBEXECDIR@$1)'
	@$$(PRINTF) '\t%s\n' $$(HIDDEN_BINARIES@$1:%='%')
	@$$(INSTALL) -d $$(LIBEXECDIR@$1)


ifneq ($$(strip $$(libraries@$1)),)
install-libraries@$1:: install-libdir@$1
	@$$(INSTALL) -m 0644 \
	  $$(foreach L,$$(libraries@$1),$$(LIBFILE.$$L@$1)) $$(LIBDIR@$1)
endif

ifneq ($$(strip $$(EXPORT_BINARIES@$1)),)
install-binaries@$1:: install-bindir@$1
	@$$(INSTALL) -m 0755 \
	  $$(foreach P,$$(EXPORT_BINARIES@$1),$$(BINFILE.$$P@$1)) $$(BINDIR@$1)
endif

ifneq ($$(strip $$(ADMIN_BINARIES@$1)),)
install-admin-binaries@$1:: install-sbindir@$1
	@$$(INSTALL) -m 0755 \
	  $$(foreach P,$$(ADMIN_BINARIES@$1),$$(BINFILE.$$P@$1)) $$(SBINDIR@$1)
endif

ifneq ($$(strip $$(HIDDEN_BINARIES@$1)),)
install-hidden-binaries@$1:: install-libexecdir@$1
	@$$(INSTALL) -m 0755 \
	  $$(foreach P,$$(HIDDEN_BINARIES@$1),$$(BINFILE.$$P@$1)) \
	  $$(LIBEXECDIR@$1)
endif

install-hidden-libraries@$1::
ifneq ($$(strip $$(hidden_libraries@$1)),)
install-hidden-libraries@$1:: install-libexecdir@$1
	@$$(INSTALL) -m 0755 \
	  $$(foreach L,$$(hidden_libraries@$1),$$(SLIBFILE.$$L@$1)) \
	  $$(LIBEXECDIR@$1)
endif

show-submodels:: show-submodel@$1

show-submodel@$1::
	@$$(PRINTF) '%-*s label: %s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)' '$1'
	@$$(PRINTF) '%-*s modules: XXX%s\n' '$$(SUBMODEL_LABEL_MAXLEN)' \
	  '$$(SUBMODEL_LABEL@$1)' '$$(SUBMODEL_OBJSFX@$1)'
	@$$(PRINTF) '%-*s shared library modules: XXX%s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' \
	  '$$(SUBMODEL_LABEL@$1)' '$$(SUBMODEL_SOBJSFX@$1)'
	@$$(PRINTF) '%-*s executables: XXX%s\n' '$$(SUBMODEL_LABEL_MAXLEN)' \
	  '$$(SUBMODEL_LABEL@$1)' '$$(SUBMODEL_SFX@$1)'
	@$$(PRINTF) '%-*s libraries: %sXXX%s\n' '$$(SUBMODEL_LABEL_MAXLEN)' \
	  '$$(SUBMODEL_LABEL@$1)' '$$(SUBMODEL_LIBPFX@$1)' \
	  '$$(SUBMODEL_LIBSFX@$1)'
	@$$(PRINTF) '%-*s shared libraries: %sXXX%s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' \
	  '$$(SUBMODEL_LABEL@$1)' '$$(SUBMODEL_SLIBPFX@$1)' \
	  '$$(SUBMODEL_SLIBSFX@$1)'

show-linkopts:: show-linkopts@$1

show-linkopts@$1::
	@$$(call PRINTLIST,'%-*s Link flags: ',\
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)',\
	  '$$(LDFLAGS@$1)')

show-opts-c:: show-opts-c@$1

show-opts-c@$1:: show-submodel@$1 show-linkopts@$1
	@$$(PRINTF) '%-*s C: %s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)' '$$(CC@$1)'
	@$$(call PRINTLIST,'%-*s C flags: ',\
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)',\
	  '$$(COMPILEFLAGS.c@$1)')

show-opts-cc:: show-opts-cc@$1

show-opts-cc@$1:: show-submodel@$1 show-linkopts@$1
	@$$(PRINTF) '%-*s C++: %s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)' '$$(CXX@$1)'
	@$$(call PRINTLIST,'%-*s C++ flags: ',\
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)',\
	  '$$(COMPILEFLAGS.cc@$1)')

show-opts-s:: show-opts-s@$1

show-opts-s@$1:: show-submodel@$1
	@$$(PRINTF) '%-*s ASM: %s\n' \
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)' '$$(AS@$1)'
	@$$(call PRINTLIST,'%-*s ASM flags: ',\
	  '$$(SUBMODEL_LABEL_MAXLEN)' '$$(SUBMODEL_LABEL@$1)',\
	  '$$(COMPILEFLAGS.s@$1)')

show-binary-%@$1::
	@$$(PRINTF) 'Binary executable %s%s: %s/%s%s\n' '$$*' \
	  '$$(SUBMODEL_LABEL_IN@$1)' '$$(BINODEPS_BINDIR)' '$$*' \
	  '$$(SUBMODEL_SFX@$1)'
	@$$(call PRINTLIST,'%s','  Libraries: ','$$($$*_lib) $$($$*_lib@$1)')
	@$$(call PRINTLIST,'%s','  Modules: ','$$($$*_obj) $$($$*_obj@$1)')

show-library-%@$1::
	@$$(PRINTF) 'Binary library %s%s: %s/%s%s%s\n' '$$*' \
	  '$$(SUBMODEL_LABEL_IN@$1)' '$$(BINODEPS_LIBDIR)' \
	  '$$(SUBMODEL_LIBPFX@$1)' '$$($$*_libname@$1)' '$$(SUBMODEL_LIBSFX@$1)'
	@$$(PRINTF) 'Binary shared library %s%s: %s/%s%s%s\n' '$$*' \
	  '$$(SUBMODEL_LABEL_IN@$1)' '$$(BINODEPS_LIBDIR)' \
	  '$$(SUBMODEL_SLIBPFX@$1)' '$$($$*_libname@$1)' \
	  '$$(SUBMODEL_SLIBSFX@$1)'
	@$$(PRINTF) '  soname: %s%s%s\n' '$$($$*_soname@$1)'
	@$$(PRINTF) '  real name: %s%s%s.%s\n' '$$(SUBMODEL_SLIBPFX@$1)' \
	  '$$($$*_libname@$1)' '$$(SUBMODEL_SLIBSFX@$1)' '$$($$*_sover@$1)'
	@$$(call PRINTLIST,'%s','  Modules: ','$$($$*_mod) $$($$*_mod@$1)')

show-binaries:: show-binaries@$1

show-binaries@$1:: $$(BINARIES@$1:%=show-binary-%@$1)

show-libraries:: show-libraries@$1

show-libraries@$1:: $$(LIBRARIES@$1:%=show-library-%@$1)

show-opts@$1:: show-opts-c@$1
show-opts@$1:: show-opts-cc@$1
show-opts@$1:: show-opts-s@$1

$$(foreach P,$$(BINARIES@$1),$$(eval $$(call DEPS4BINARIESINSUBMODEL,$$P,$1)))

$$(foreach P,$$(LIBRARIES@$1),$$(eval $$(call DEPS4LIBRARIESINSUBMODEL,$$P,$1)))

endef

## $1 is the program, $2 is the submodel.
define DEPS4BINARIESINSUBMODEL
show-binary-$1:: show-binary-$1@$2

endef

## $1 is the program, $2 is the submodel.
define DEPS4LIBRARIESINSUBMODEL
show-library-$1:: show-library-$1@$2

endef

define PP_COPY_RULE
## When preprocessed source files are copied to the .o directory,
## insert a directive to make error messages refer to the original
## file.
$$(BINODEPS_SRCDIR_DYN)/%.$1: $$(BINODEPS_SRCDIR)/%.$1
	@$$(PRINTF) '[CP PP %s] %s\n' '$2' '$$*'
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_SRCDIR_DYN)/CACHEDIR.TAG'
	@$$(PRINTF) > '$$@-tmp' '#line 1 "%s"\n' '$$<'
	@$$(CAT) '$$<' >> '$$@-tmp'
	@$$(MV) '$$@-tmp' '$$@'

## Keep the copied files around.
.PRECIOUS: $$(BINODEPS_SRCDIR_DYN)/%.$1

endef

define NOPP_COPY_RULE
## Non-preprocessed source files are simply copied to the .o
## directory.
$$(BINODEPS_SRCDIR_DYN)/%.$1: $$(BINODEPS_SRCDIR)/%.$1
	@$$(PRINTF) '[CP %s] %s\n' '$2' '$$*'
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_SRCDIR_DYN)/CACHEDIR.TAG'
	@$$(CP) '$$<' '$$@-tmp'
	@$$(MV) '$$@-tmp' '$$@'

## Keep the copied files around.
.PRECIOUS: $$(BINODEPS_SRCDIR_DYN)/%.$1

endef

## Install with mode $1 (e.g., 0755) into $2 (e.g.,
## /usr/local/share/app) from $3 (e.g., src/share) files matching $5
## if they are exactly in subdirectory $4 (e.g., x/y/z/).  The
## subdirectory $4 and the files in $5 are relative to both $2 and $3,
## and must end in a slash.  Use "./" as $4 for the top level.
define GENDIR_INSTALL_COMMANDS
$(INSTALL) -d '$2/$4'
$(INSTALL) -m '$1' \
  $(foreach F,$(call INDIR,$4,$(call ALTFILES,$5)),$3/$4$F) \
  '$2/$4'

endef

## Install with mode $1 (e.g., 0755) into $2 (e.g.,
## /usr/local/share/app) from $3 (e.g., src/share) subfiles of $3
## listed in $4, preserving paths in $2.
define RECURSIVE_INSTALL
$(foreach D,$(call DIRS,$4),$(call GENDIR_INSTALL_COMMANDS,$1,$2,$3,$D,$4))


endef



## Allow RISC OS applications to contain modules compiled from C.  $1
## is the application, $2 is the relocatable module.
define RISCOS_MODULE_DEFS
ifdef $1.$2.modloc
$1_rof += $$($1.$2.modloc),ffa
endif

endef


## By default, a RISC OS zip contains only the application of the same
## name.
define RISCOS_ZIP_DEFS
$1_apps ?= $1

$1_zipname ?= $1

$1_zipdesc ?= $1

$1_zipversion ?= $$(VERSION)

$1_zipversionsfx=\
$$(if $$($1_zipversion),-$$($1_zipversion))

$1_zipfile=$$($1_zipname)-riscos$$($1_zipversionsfx).zip

endef



## Just use the internal RISC OS application name if an external name
## isn't defined.
define RISCOS_APP_DEFS
$1_appname ?= $1

ifdef $1_runimage
$1_rof += !RunImage,ff8
endif

$$(foreach P,$$(BINARIES@riscos-rm),\
   $$(eval $$(call RISCOS_MODULE_DEFS,$1,$$P)))

endef






define DEFS4BINARIES
BINFILE.$1@$2=$$(BINODEPS_BINDIR)/$1$$(SUBMODEL_SFX@$2)
BINOBJS.$1@$2=$$(foreach O,$$($1_obj) $$($1_obj@$2), \
		 $$(BINODEPS_OBJDIR)/$$O$$(SUBMODEL_OBJSFX@$2))
BINARS.$1@$2=$$(foreach O,$$($1_ar) $$($1_ar@$2), $$(LIBFILE.$$O@$2))
BINSOS.$1@$2=$$(foreach O,$$($1_so) $$($1_so@$2), $$(SLIBFILE.$$O@$2))

endef


## Define rules for building each binary executable. $1 is the
## program, $2 is the submodel, $3 is the language macro suffix (e.g.,
## selecting LINK.c rather than LINK.cc), $4 is the short language
## name.
define DEPS4BINARIES
## Make sure we can detect changes to the list of object files that
## make up each binary executable.
$$(BINODEPS_TMPDIR)/progobjlisted.$1.$2:
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_TMPDIR)/CACHEDIR.TAG'
	@$$(PRINTF) > '$$(BINODEPS_TMPDIR)/progobjlist.$1.$2-tmp' \
	  '%s\n' $$(sort $$($1_obj) $$($1_obj@$2))
$$(BINODEPS_TMPDIR)/progobjlist.$1.$2: | $$(BINODEPS_TMPDIR)/progobjlisted.$1.$2
$$(BINODEPS_TMPDIR)/progobjlist.$1.$2: $$(BINODEPS_TMPDIR)/progobjlisted.$1.$2
	@$$(call CPCMP,$$@-tmp,$$@,$1 object list$$(SUBMODEL_LABEL_IN@$2))

## Build binaries.
$$(BINFILE.$1@$2): $$(BINODEPS_TMPDIR)/progobjlist.$1.$2 $$(BINOBJS.$1@$2)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_BINDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[Link %s] %s%s:\n' '$4' '$1' '$(SUBMODEL_LABEL_IN@$2)'
	@$$(call PRINTLIST,'%s','  Libraries: ','$$($1_lib) $$($1_lib@$2)')
	@$$(call PRINTLIST,'%s','  Modules: ','$$($1_obj) $$($1_obj@$2)')
	@$$(LINK.$3@$2) -o '$$@' $$(BINOBJS.$1@$2) $$(BINARS.$1@$2) \
	  $$(BINSO.$1@$2) $$($1_lib) $$($1_lib@$2)

endef



## Define rules to copy RISC OS modules from the binaries to a
## filetyped name in the RISC OS output directory.
define RISCOS_MODULE_RULES
ifdef $1.$2.modloc
$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/$$($1.$2.modloc),ffa: \
  $$(BINODEPS_BINDIR)/$2$$(SUBMODEL_SFX@riscos-rm)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[CP] %s->%s%s\n' '$2' '$1' '$(SUBMODEL_LABEL_IN@riscos-rm)'
	@$$(CP) --reflink=auto '$$<' '$$@'
endif

endef





## Allow libraries to have distinct internal and external names.  List
## all module files of a library.  Define the full soname for a shared
## library.  $1 is the library, $2 is the submodel.
define DEFS4LIBRARIES
$1_libname ?= $1
$1_libname@$2 ?= $$($1_libname)
LIBLEAF.$1@$2=$$(SUBMODEL_LIBPFX@$2)$$($1_libname@$2)$$(SUBMODEL_LIBSFX@$2)
SLIBLEAF.$1@$2=$$(SUBMODEL_SLIBPFX@$2)$$($1_libname@$2)$$(SUBMODEL_SLIBSFX@$2)
LIBFILE.$1@$2=$$(BINODEPS_LIBDIR)/$$(LIBLEAF.$1@$2)
SLIBFILE.$1@$2=$$(BINODEPS_LIBDIR)/$$(SLIBLEAF.$1@$2)
LIBOBJS.$1@$2=$$(foreach O,$$($1_mod) $$($1_mod@$2), \
		 $$(BINODEPS_OBJDIR)/$$O$$(SUBMODEL_OBJSFX@$2))
SLIBOBJS.$1@$2=$$(foreach O,$$($1_mod) $$($1_mod@$2), \
		 $$(BINODEPS_OBJDIR)/$$O$$(SUBMODEL_SOBJSFX@$2))

$1_sover@$2 ?= $$($1_sover)
$1_SOMAJOR@$2 ?= $$(word 1,$$(subst .,$$(binodeps_space),$$($1_sover@$2)))
$1_soname@$2 ?= $$(SUBMODEL_SLIBPFX@$2)$$($1_libname@$2)$$(SUBMODEL_SLIBSFX@$2).$$($1_SOMAJOR@$2)

endef

## $1 is the library, $2 is the submodel, $3 is the group (INSTALLED,
## TEST).
define DEFS4X_LIBRARIES
$3_LIBFILES += $$(LIBFILE.$1@$2)

ifneq ($$($1_sover@$2),)
$3_LIBFILES += $$(SLIBFILE.$1@$2)
endif

endef


define DEFS4HIDDEN_LIBRARIES
HIDDEN_LIBFILES += $$(SLIBFILE.$1@$2)

endef



define DEPS4INSTALLED_LIBRARIES
ifneq ($$($1_sover@$2),)
@install-libraries@$2:: install-libdir@$2
	@$$(INSTALL) -m 0755 $$(SLIBFILE.$1@$2) \
	  $$(LIBDIR)/$$(SLIBLEAF.$1@$2).$$($1_sover@$2)
	@$$(LN) -sfn $$(LIBDIR)/$$(SLIBLEAF.$1@$2).$$($1_sover@$2) \
	  $$(LIBDIR)/$$(SLIBLEAF.$1@$2)
endif

endef



## Define rules for building each binary library.  $1 is the library,
## $2 is the submodel.
define DEPS4LIBRARIES
## Make sure we can detect changes to the list of object files that
## make up each binary library.
$$(BINODEPS_TMPDIR)/libobjlisted.$1.$2:
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_TMPDIR)/CACHEDIR.TAG'
	@$$(PRINTF) > '$$(BINODEPS_TMPDIR)/libobjlist.$1.$2-tmp' '%s\n' \
	  $$(sort $$($1_mod) $$($1_mod@$2))
$$(BINODEPS_TMPDIR)/libobjlist.$1.$2: | $$(BINODEPS_TMPDIR)/libobjlisted.$1.$2
$$(BINODEPS_TMPDIR)/libobjlist.$1.$2: $$(BINODEPS_TMPDIR)/libobjlisted.$1.$2
	@$$(call CPCMP,$$@-tmp,$$@,$1 object list$(SUBMODEL_LABEL_IN@$2))

## Define the build rule.
$$(LIBFILE.$1@$2): $$(BINODEPS_TMPDIR)/libobjlist.$1.$2 $$(LIBOBJS.$1@$2)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_LIBDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[Link lib] %s%s:\n' '$1' '$(SUBMODEL_LABEL_IN@$2)'
	@$$(call PRINTLIST,'%s','  Modules: ','$$($1_mod) $$($1_mod@$2)')
	@$$(RM) '$$@'
	@$$(AR@$2) r '$$@' $$(LIBOBJS.$1@$2)
	@$$(RANLIB@$2) '$$@'

$$(SLIBFILE.$1@$2): $$(BINODEPS_TMPDIR)/libobjlist.$1.$2 $$(SLIBOBJS.$1@$2)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_LIBDIR)/CACHEDIR.TAG'
	@$$(PRINTF) '[Link shared lib] %s%s:\n' '$1' '$(SUBMODEL_LABEL_IN@$2)'
	@$$(call PRINTLIST,'%s','  Modules: ','$$($1_mod) $$($1_mod@$2)')
	@$$(RM) '$$@'
	@$$(call SAR@$2,$$@,$$($1_soname@$2),$$(SLIBOBJS.$1@$2))

endef



## Source files of the form foo/bar/baz.h appear on RISC OS
## filesystems as foo.bar.h.baz (where . is a directory separator).
## Knowing the list of source directories, we can generate rules for
## each one to copy the conventionally named files to RISC OS form.
## We also transpose . and /, and add the type suffix, because we're
## still looking at the files from a Unix point of view.

define RISCOS_APP_SFXDIR_RULES
$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Library/$2$3/%,fff: \
  $$(BINODEPS_SRCDIR)/$2%.$3
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS export] %s <%s%s.%s>\n' '$1' '$2' '$$*' '$3'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Source/$2$3/%,fff: \
  $$(BINODEPS_SRCDIR)/$2%.$3
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS source] %s %s%s.%s\n' '$1' '$2' '$$*' '$3'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Library/$2$3/%,fff: \
  $$(BINODEPS_SRCDIR_DYN)/$2%.$3
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS export] %s <%s%s.%s>\n' '$1' '$2' '$$*' '$3'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Source/$2$3/%,fff: \
  $$(BINODEPS_SRCDIR_DYN)/$2%.$3
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS source] %s %s%s.%s\n' '$1' '$2' '$$*' '$3'
	@$$(CP) --reflink=auto '$$<' '$$@'

endef

define RISCOS_APP_RULES
$$(foreach sfx,$$(RISCOS_SUFFIXES), \
   $$(eval $$(call RISCOS_APP_SFXDIR_RULES,$1,,$$(sfx))) \
   $$(foreach dir,$$(SOURCE_DIRS),$$(eval $$(call RISCOS_APP_SFXDIR_RULES,$1,$$(dir)/,$$(sfx)))))


$$(foreach P,$$(BINARIES@riscos-rm), \
   $$(eval $$(call RISCOS_MODULE_RULES,$1,$$P)))

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/%,faf: $$(BINODEPS_DOCDIR)/%.html
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS HTML] %s %s\n' '$1' '$$*'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/%,fff: $$(BINODEPS_DOCDIR)/%
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS text] %s %s\n' '$1' '$$*'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Docs/%,fff: $$(BINODEPS_DOCDIR)/%
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS text] %s %s\n' '$1' '$$*'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Library/o/%,ffd: \
  $$(BINODEPS_LIBDIR)/$$(SUBMODEL_LIBPFX@default)%$$(SUBMODEL_LIBSFX@default)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS export] %s lib%s.a\n' '$1' '$$*'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/%: \
  $$(BINODEPS_SHAREDIR_RISCOS)/$1/%
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS file] %s %s\n' '$1' '$$*'
	@$$(CP) --reflink=auto '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/Library/%,ff8: \
  $$(BINODEPS_BINDIR)/%$$(SUBMODEL_SFX@default)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS absolute] %s %s\n' '$1' '$$<'
	@$$(ELF2AIF) '$$<' '$$@'

$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/%,ffa: \
  $$(BINODEPS_BINDIR)/%$$(SUBMODEL_SFX@riscos-rm)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS absolute] %s %s\n' '$1' '$$<'
	@$$(CP) --reflink=auto '$$<' '$$@'

ifdef $1_runimage
$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/!RunImage,ff8: \
  $$(BINODEPS_BINDIR)/$$($1_runimage)$$(SUBMODEL_SFX@default)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[Copy RISC OS run image] %s %s\n' '$1' '$$<'
	@$$(ELF2AIF) '$$<' '$$@'

endif

riscos-app-$1:: $$($1_rof:%=$$(BINODEPS_OUTDIR_RISCOS)/$$($1_appname)/%)

riscos-apps:: riscos-app-$1

endef

define RISCOS_ZIP_RULES
riscos-zip-$1 riscos-zips:: $$(BINODEPS_ZIPDIR_RISCOS)/$1-riscos.zip

$$(BINODEPS_ZIPDIR_RISCOS)/$1-riscos.zip: \
  $$(foreach A,$$($1_apps), \
     $$($$A_rof:%=$$(BINODEPS_OUTDIR_RISCOS)/$$($$A_appname)/%)) \
  $$($1_zrof:%=$$(BINODEPS_OUTDIR_RISCOS)/%)
	@$$(MKDIR) '$$(@D)'
	@$$(TOUCH) '$$(BINODEPS_ZIPDIR_RISCOS)/CACHEDIR.TAG'
	@$$(PRINTF) '[RISC OS zip] %s\n' '$1'
	@$$(RM) '$$@'
	@$$(BINODEPS_REAL_HOME)/share/binodeps/dirzip \
	  --array CD $$(words $$(CD)) $$(CD:%='%') \
	  --array ZIP $$(words $$(RISCOS_ZIP)) $$(RISCOS_ZIP:%='%') \
	  --out='$$@' --dir='$$(BINODEPS_OUTDIR_RISCOS)' -, -rq -- \
	  $$(foreach A,$$($1_apps), \
	     $$($$A_rof:%=$$($$A_appname)/%)) $$($1_zrof:%=%)
# @$$(CD) $$(BINODEPS_OUTDIR_RISCOS) ; \
# $$(RISCOS_ZIP) -rq '$$(abspath $$@)' \
#   $$(foreach A,$$($1_apps), \
#      $$($$A_rof:%=$$($$A_appname)/%)) $$($1_zrof:%=%)

install-riscos-zip-$1:: install-riscoszipdir
	@$$(PRINTF) '  %s -> %s\n' '$1-riscos.zip' '$$($1_zipfile)'
	@$$(ZIPCMP) -q $$(BINODEPS_ZIPDIR_RISCOS)/$1-riscos.zip \
	  $$(ZIPDIR_RISCOS)/$$($1_zipfile) 2> /dev/null || \
	  $$(INSTALL) -T $$(BINODEPS_ZIPDIR_RISCOS)/$1-riscos.zip \
	  $$(ZIPDIR_RISCOS)/$$($1_zipfile)

install-riscos-zips:: install-riscos-zip-$1

endef





### Generated definitions

$(foreach T,$(SUBMODELS_SORTED),$(eval $(call DEFS4SUBMODELS,$T)))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(BINARIES@$T),$(eval $(call DEFS4BINARIES,$L,$T))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(LIBRARIES@$T),$(eval $(call DEFS4LIBRARIES,$L,$T))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(libraries@$T),$(eval $(call DEFS4X_LIBRARIES,$L,$T,INSTALLED))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(hidden_libraries@$T),$(eval $(call DEFS4HIDDEN_LIBRARIES,$L,$T))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(test_libraries@$T),$(eval $(call DEFS4X_LIBRARIES,$L,$T,TEST))))

$(foreach Z,$(riscos_zips),$(eval $(call RISCOS_ZIP_DEFS,$Z)))

$(foreach A,$(RISCOS_APPS),$(eval $(call RISCOS_APP_DEFS,$A)))







### Generated dependencies

## Rules for building binary executables

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach P,$(BINARIES.c@$T),$(eval $(call DEPS4BINARIES,$P,$T,c,C))))


## Rules for building static libraries

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach P,$(BINARIES.cc@$T),$(eval $(call DEPS4BINARIES,$P,$T,cc,C++))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(LIBRARIES@$T),$(eval $(call DEPS4LIBRARIES,$L,$T))))

$(foreach T,$(SUBMODELS_SORTED),\
  $(foreach L,$(libraries@$T),$(eval $(call DEPS4INSTALLED_LIBRARIES,$L,$T))))

## TODO: Is there a way to stop the building of these targets from
## suppressing the inactivity message?
# $(foreach T,$(SUBMODELS_SORTED),$(BINARIES@$T:%=$(BINODEPS_TMPDIR)/progobjlisted.%.$T))
# $(foreach T,$(SUBMODELS_SORTED),$(BINARIES@$T:%=$(BINODEPS_TMPDIR)/progobjlist.%.$T))
# $(foreach T,$(SUBMODELS_SORTED),$(LIBRARIES@$T:%=$(BINODEPS_TMPDIR)/libobjlisted.%.$T))
# $(foreach T,$(SUBMODELS_SORTED),$(LIBRARIES@$T:%=$(BINODEPS_TMPDIR)/libobjlist.%.$T))


## Compilation rules

$(foreach T,$(SUBMODELS_SORTED),$(eval $(call DEPS4SUBMODELS,$T)))




## Copy C and C++ with #line directive.
$(eval $(call PP_COPY_RULE,S,ASM PP src))
$(eval $(call NOPP_COPY_RULE,s,ASM src))
$(eval $(call PP_COPY_RULE,c,C src))
$(eval $(call PP_COPY_RULE,cc,C++ src))
$(eval $(call PP_COPY_RULE,h,C hdr))
$(eval $(call PP_COPY_RULE,hh,C++ hdr))





## RISC OS zips and applications

install-riscos-zips::
	@$(PRINTF) 'Installing RISC OS zips in %s:\n' '$(ZIPDIR_RISCOS)'
	@$(PRINTF) '\t%s\n' $(riscos_zips)

$(foreach A,$(RISCOS_APPS),$(eval $(call RISCOS_APP_RULES,$A)))
$(foreach Z,$(riscos_zips),$(eval $(call RISCOS_ZIP_RULES,$Z)))




## Safely include generated dependencies from the previous invocation.

-include $(call BINODEPS_ABSPATH,$(foreach T,$(SUBMODELS_SORTED),\
	   $(ALL_OBJECTS:%=$(BINODEPS_OBJDIR)/%$(SUBMODEL_SFX@$T).static.mk)))

-include $(call BINODEPS_ABSPATH,$(foreach T,$(SUBMODELS_SORTED),\
	   $(ALL_OBJECTS:%=$(BINODEPS_OBJDIR)/%$(SUBMODEL_SFX@$T).shared.mk)))


RISCOS_SHLIBRARIES=$(patsubst %_sover@default,%,$(filter %_sover@default,$(.VARIABLES)))

## $1 is the library name.
define DEPS4RISCOS_LIBRARIES
$$(BINODEPS_OUTDIR_RISCOS)/!Boot/Resources/!SharedLibs/lib/lib$1.so.$$($1_sover@default),e1f: $$(BINODEPS_LIBDIR)/$$(SUBMODEL_SLIBPFX@default)$1$$(SUBMODEL_SLIBSFX@default)
	@$$(PRINTF) '[RISC OS] lib%s.so.%s\n' '$1' '$$($1_sover@default)'
	@$$(MKDIR) "$$(@D)"
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(CP) "$$<" "$$@"
$$(BINODEPS_OUTDIR_RISCOS)/!Boot/Resources/!SharedLibs/lib/lib$1.so.$$($1_SOMAJOR@default),1cf:
	@$$(PRINTF) '[RISC OS] lib%s.so.%s -> lib%s.so.%s\n' '$1' \
	  '$$($1_SOMAJOR@default)' '$1' '$$($1_sover@default)'
	@$$(MKDIR) "$$(@D)"
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(BINODEPS_REAL_HOME)/share/binodeps/rosymlink \
	  'lib$1/so/$$(subst .,/,$$($1_sover@default))' > '$$@'
$$(BINODEPS_OUTDIR_RISCOS)/!Boot/Resources/!SharedLibs/lib/lib$1.so,1cf:
	@$$(PRINTF) '[RISC OS] lib%s.so -> lib%s.so.%s\n' '$1' \
	  '$1' '$$($1_sover@default)'
	@$$(MKDIR) "$$(@D)"
	@$$(TOUCH) '$$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$$(BINODEPS_REAL_HOME)/share/binodeps/rosymlink \
	  'lib$1/so/$$(subst .,/,$$($1_sover@default))' > '$$@'

endef

$(foreach L,$(RISCOS_SHLIBRARIES),$(eval $(call DEPS4RISCOS_LIBRARIES,$L)))


### Other special rules

## Copy non-preprocessed files.
$(BINODEPS_SRCDIR_DYN)/%: $(BINODEPS_SRCDIR)/%
	@$(PRINTF) '[CP] %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_SRCDIR_DYN)/CACHEDIR.TAG'
	@$(CP) '$<' '$@'

## RISC OS modules

$(BINODEPS_SRCDIR_DYN)/%.s: $(BINODEPS_SRCDIR_DYN)/%.cmhg
	@$(PRINTF) '[CMHG ASM] %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_SRCDIR_DYN)/CACHEDIR.TAG'
	@$(CMHG) $(CMHGFLAGS) -s '$@' '$<'

$(BINODEPS_SRCDIR_DYN)/%.h: $(BINODEPS_SRCDIR_DYN)/%.cmhg
	@$(PRINTF) '[CMHG Header] %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_SRCDIR_DYN)/CACHEDIR.TAG'
	@$(CMHG) $(CMHGFLAGS) -d '$@' '$<'

$(BINODEPS_HDRDIR)/%: $(BINODEPS_SRCDIR)/%
	@$(PRINTF) '[OUT] %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_HDRDIR)/CACHEDIR.TAG'
	@$(CP) '$<' '$@'

$(BINODEPS_HDRDIR)/%: $(BINODEPS_SRCDIR_DYN)/%
	@$(PRINTF) '[OUT] * %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_HDRDIR)/CACHEDIR.TAG'
	@$(CP) '$<' '$@'

## RISC OS applications

$(BINODEPS_OUTDIR_RISCOS)/%: $(BINODEPS_SHAREDIR_RISCOS)/%
	@$(PRINTF) '[Copy RISC OS file] %s\n' '$*'
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(BINODEPS_OUTDIR_RISCOS)/CACHEDIR.TAG'
	@$(CP) --reflink=auto '$<' '$@'





### Some diagnostic rules

show-submodels::

show-opts:: show-opts-c
show-opts:: show-opts-cc
show-opts:: show-opts-s


## Some basic housekeeping
tidy::

clean:: tidy
	@$(RM) -r $(BINODEPS_OBJDIR)
	@$(RM) -r $(BINODEPS_TMPDIR)

blank:: clean
	@$(RM) -r $(BINODEPS_BINDIR)
	@$(RM) -r $(BINODEPS_LIBDIR)
	@$(RM) -r $(BINODEPS_HDRDIR)
	@$(RM) -r $(BINODEPS_OUTDIR_RISCOS)
	@$(RM) -r $(BINODEPS_ZIPDIR_RISCOS)
	@$(RM) -r $(BINODEPS_OUTDIR)


## Convenient targets

installed-binaries:: \
  $(foreach T,$(SUBMODELS_SORTED),\
    $(foreach P,$(INSTALLED_BINARIES@$T),$(BINFILE.$P@$T)))
installed-libraries:: $(headers:%=$(BINODEPS_HDRDIR)/%)
installed-libraries:: $(INSTALLED_LIBFILES) $(HIDDEN_LIBFILES)
$(INSTALLED_LIBFILES): $(headers:%=$(BINODEPS_HDRDIR)/%)

test-binaries:: \
  $(foreach T,$(SUBMODELS_SORTED),\
    $(foreach P,$(TEST_BINARIES@T),$(BINFILE.$P@$T)))
test-libraries:: $(TEST_LIBFILES)


## Standard installation rules
install-dev:: install-libraries install-headers


install-incdir::
	@$(INSTALL) -d $(INCDIR)

install-hidden-scripts::

install-sharedir::
	@$(INSTALL) -d $(SHAREDIR)

ifneq ($(strip $(hidden_scripts)),)
install-hidden-scripts::
	@$(PRINTF) 'Installing hidden scripts in %s:\n' '$(SHAREDIR)'
	@$(PRINTF) '\t%s\n' $(hidden_scripts:%='%')
	@$(call RECURSIVE_INSTALL,0755,$(SHAREDIR),$(BINODEPS_SHAREDIR),$(hidden_scripts))
endif
# @$(foreach D,$(call DIRS,$(hidden_scripts)),$(call GENDIR_INSTALL_COMMANDS,0755,$(SHAREDIR),$(BINODEPS_SHAREDIR),$D,$(hidden_scripts)))



install-library-scripts::

install-libexecdir::
	@$(INSTALL) -d $(LIBEXECDIR)

ifneq ($(strip $(library_scripts)),)
install-library-scripts::
	@$(PRINTF) 'Installing library scripts in %s:\n' '$(LIBEXECDIR)'
	@$(PRINTF) '\t%s\n' $(library_scripts:%='%')
	@$(call RECURSIVE_INSTALL,0755,$(LIBEXECDIR),$(BINODEPS_SHAREDIR),$(library_scripts))
endif
# @$(foreach D,$(call DIRS,$(library_scripts)),$(call GENDIR_INSTALL_COMMANDS,0755,$(LIBEXECDIR),$(BINODEPS_SHAREDIR),$D,$(library_scripts)))



install-admin-scripts::

install-sbindir::
	@$(INSTALL) -d $(SBINDIR)

ifneq ($(strip $(admin_scripts)),)
install-admin-scripts:: install-sbindir
	@$(PRINTF) 'Installing system binaries/scripts in %s:\n' '$(SBINDIR)'
	@$(PRINTF) '\t%s\n' $(admin_scripts:%='%')
	@$(INSTALL) -m 0755 $(admin_scripts:%=$(BINODEPS_SCRIPTDIR)/%) \
	  $(SBINDIR)
endif



install-scripts::

install-bindir::
	@$(INSTALL) -d $(BINDIR)

ifneq ($(strip $(scripts)),)
install-scripts:: install-bindir
	@$(PRINTF) 'Installing scripts in %s:\n' '$(BINDIR)'
	@$(PRINTF) '\t%s\n' $(scripts)
	@$(INSTALL) -m 0755 $(scripts:%=$(BINODEPS_SCRIPTDIR)/%) $(BINDIR)
endif



install-riscos::

install-riscosdir::
	@$(INSTALL) -d $(APPDIR_RISCOS)

ifneq ($(strip $(RISCOS_APPS)),)
install-riscos:: install-riscosdir
	@$(PRINTF) 'Installing RISC OS apps in %s:\n' '$(APPDIR_RISCOS)'
	@$(PRINTF) '\t%s\t(%s)\n' \
	  $(foreach A,$(RISCOS_APPS),'$A' '$($A_appname)')
	@$(TAR) cf - -C $(BINODEPS_OUTDIR_RISCOS) \
	  $(foreach A,$(RISCOS_APPS),$($A_rof:%=$($A_appname)/%)) | \
	  $(TAR) xf - -C $(APPDIR_RISCOS)
endif

install-riscoszipdir::
	@$(INSTALL) -d $(ZIPDIR_RISCOS)

## Install the headers.  Everything in $(headers) from
## $(BINODEPS_SRCDIR)/ is copied to $(INCDIR), preserving the
## hierarchy.
install-headers::
	@$(PRINTF) 'Installing headers in %s:\n' '$(INCDIR)'
	@$(PRINTF) '\t<%s>\n' $(headers:%='%')
	@$(call RECURSIVE_INSTALL,0644,$(INCDIR),$(BINODEPS_HDRDIR),$(headers))
#	@$(foreach D,$(HEADER_DIRS),$(call HEADER_INSTALL_COMMANDS,$D))



## Install the datafiles.  Everything in $(datafiles) from
## $(BINODEPS_SHAREDIR)/ is copied to $(SHAREDIR), preserving the
## hierarchy.
install-data::
	@$(PRINTF) 'Installing datafiles in %s:\n' '$(SHAREDIR)'
	@$(PRINTF) '\t%s\n' $(datafiles:%='%')
	@$(call RECURSIVE_INSTALL,0644,$(SHAREDIR),$(BINODEPS_SHAREDIR),$(datafiles))
#	@$(foreach D,$(DATAFILE_DIRS),$(call DATAFILE_INSTALL_COMMANDS,$D))

-include binodeps-user-ext.mk


## RISC OS shared libraries: ,1cf is the symlink type.  ,e1f is surely
## the ELF type.  Create directory !Boot/Resources/!SharedLibs/lib.
## There, place libXXX.so.1.2.3,e1f, and symlink libXXX.so.1,1cf and
## libXXX.so,1cf to it.  A link contains, L I N K, followed by a
## 4-byte filename length, little-endian, then the characters for the
## relative filename.  Use slashes for dots.
