## Copyright (c) 2018, Regents of the University of Lancaster
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
##  * Neither the name of the copyright holder nor the names of
##    its contributors may be used to endorse or promote products derived
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


PROTOC.py ?= protoc

PYTHON_VERSIONS += 2.7
PYTHON_VERSIONS += 3
PYTHON_VERSIONS += 3.5

define PYTHON_DEFS
PYTHON$1 ?= python$1

endef
$(foreach V,$(PYTHON_VERSIONS),$(eval $(call PYTHON_DEFS,$V)))

define PYTHON_TREE_DEFS
$1_pyroot ?= src/python/$1
$1_pyname ?= $1
# $1_py$2root ?= $($1_pyroot)
# $1_py$2name ?= $($1_pyname)

pyfiles_$1_raw=$$(shell $$(FIND) $$($1_pyroot) -name "*.py" -printf '%P\n')
pyfiles_$1=$$(pyfiles_$1_raw:%.py=%)

endef
$(foreach V,$(PYTHON_VERSIONS),$(foreach T,$(python$V_zips),$(eval $(call PYTHON_TREE_DEFS,$T,$V))))


define PYTHON_LIB_DEFS
PYTHON$2_LIBDIR ?= $(LIBDIR)/python$2/site-packages
python$2_files-$1=$$(shell $$(FIND) '$1' -name "*.py" -printf '%P\n')
python$2_dsfiles-$1=$$(python$2_files-$1:%=./%)
python$2_subdirs-$1=$$(sort $$(dir $$(python$2_dsfiles-$1)))

endef
$(foreach V,$(PYTHON_VERSIONS),$(foreach D,$(python$V_libs),$(eval $(call PYTHON_LIB_DEFS,$D,$V))))

define PYTHON_SUBDIR_CMDS
$(call PRINTLIST,'  %s: ','$(1:%/=%)/$(2:./%=%)','$(foreach F,$(filter-out $(foreach SD,$(filter-out $2,$(filter $2%,$(python$3_subdirs-$1))),$(SD)%),$(filter $2%,$(python$3_dsfiles-$1))),$(F:$2%=%))')
$(INSTALL) -d '$(PYTHON$3_LIBDIR)/$(2:./%=%)'
$(INSTALL) -m 0644 $(foreach F,$(filter-out $(foreach SD,$(filter-out $2,$(filter $2%,$(python$3_subdirs-$1))),$(SD)%),$(filter $2%,$(python$3_dsfiles-$1))),'$(1:%/=%)/$(F:./%=%)') '$(PYTHON$3_LIBDIR)/$(2:./%=%)'

endef

define PYTHON_CMDS
$(foreach SD,$(python$2_subdirs-$1),$(call PYTHON_SUBDIR_CMDS,$1,$(SD),$2))

endef

install-python:: install-python-modules install-python-zips

define PYTHON_ZIP_CMDS
$(INSTALL) -d '$(dir $(SHAREDIR)/python$2/$($1_pyname))'
$(INSTALL) -m 0644 '$(BINODEPS_OUTDIR)/python$2/$1.zip' \
  '$(SHAREDIR)/python$2/$($1_pyname).zip'

endef

define PYTHON_TREE_DEPS
## Copy Python source from source directory.
$$(BINODEPS_TMPDIR)/python$2/src/$1/%.py: $$($1_pyroot)/%.py
	@$$(PRINTF) '[Python %s ZIP] %s Copy source %s\n' '$2' '$1' '$$*'
	@$$(MKDIR) '$$(@D)'
	@$$(CP) '$$<' '$$@'

## Copy Protobuf-generated source.
$$(BINODEPS_TMPDIR)/python$2/src/$1/%_pb2.py: \
  $$(BINODEPS_TMPDIR)/protobuf/python/%_pb2.py
	@$$(PRINTF) '[Python %s ZIP] %s Copy protobuf %s\n' '$2' '$1' '$$*'
	@$$(MKDIR) '$$(@D)'
	@$$(CP) '$$<' '$$@'

$$(BINODEPS_TMPDIR)/python$2/zips/$1.list: \
  $$(BINODEPS_TMPDIR)/python$2/zips/$1.listed

$$(BINODEPS_OUTDIR)/python$2/$1.zip: \
  $$(BINODEPS_TMPDIR)/python$2/zips/$1.list \
  $$(pyfiles_$1:%=$$(BINODEPS_TMPDIR)/python$2/src/$1/%.py) \
  $$($1_pyproto:%=$$(BINODEPS_TMPDIR)/python$2/src/$1/%_pb2.py)

endef

## Build Python from Protobuf definitions.  There seems to be a
## one-to-one relationship, and the result is version-independent.
$(BINODEPS_TMPDIR)/protobuf/python/%_pb2.py: $(BINODEPS_PROTODIR)/%.proto
	@$(PRINTF) '[Protobuf->Python] %s\n' '$*'
	@$(MKDIR) '$(BINODEPS_TMPDIR)/protobuf/python/'
	@$(PROTOC.py) '-I$(BINODEPS_PROTODIR)' \
	  --python_out='$(BINODEPS_TMPDIR)/protobuf/python/' '$<'

define PYTHON_VDEPS
install-python:: install-python$1
install-python$1:: install-python$1-modules
install-python$1:: install-python$1-zips

install-python-modules:: install-python$1-modules

install-python$1-modules::
	@$$(PRINTF) 'Installing Python %s libraries in [%s]:\n' '$1' \
	  '$$(PYTHON$1_LIBDIR)'
	@$$(foreach D,$$(python$1_libs),$$(call PYTHON_CMDS,$$D,$1))

install-python-zips:: install-python$1-zips

install-python$1-zips::
	@$$(PRINTF) 'Installing Python %s apps in %s:\n' '$1' \
	  '$$(SHAREDIR)/python$1'
	@$$(PRINTF) '  %s\n' $$(python$1_zips:%='%')
	@$$(foreach Z,$$(python$1_zips),$$(call PYTHON_ZIP_CMDS,$$Z,$1))

python-zips:: python-zips$1

python-zips$1:: \
  $$(foreach T,$$(python$1_zips),$$(BINODEPS_OUTDIR)/python$1/$$T.zip)

#-include $$(python$1_zips:%=$$(BINODEPS_TMPDIR_LOCAL)/python$1/zips/%.mk)

$$(foreach T,$$(python$1_zips),$$(eval $$(call PYTHON_TREE_DEPS,$$T,$1)))

$$(BINODEPS_TMPDIR)/python$1/zips/%.listed:
	@$$(MKDIR) '$$(@D)'
	@$$(PRINTF) '%s\n' > '$$(BINODEPS_TMPDIR)/python$1/zips/$$*.list-tmp' \
	  $$(sort $$(pyfiles_$$*:%=%.py) $$($$*_pyproto:%=%_pb2.py))

$$(BINODEPS_TMPDIR)/python$1/zips/%.list:
	@$$(call CPCMP,$$@-tmp,$$@,Python $1 zip $$* list)

$$(BINODEPS_OUTDIR)/python$1/%.zip:
	@$$(PRINTF) '[Python %s ZIP] %s from %s\n' '$1' '$$*' '$$($$*_pyroot)'
	@$$(CD) '$$(BINODEPS_TMPDIR)/python$1/src/$$*' ; \
	  $$(PYTHON$1) -m compileall -b -q -f \
	  $$(pyfiles_$$*:%=%.py) $$($$*_pyproto:%=%_pb2.py)
	@$$(MKDIR) '$$(dir $$(BINODEPS_TMPDIR)/python$1/zips/$$*.zip)'
	@$$(RM) '$$(BINODEPS_TMPDIR)/python$1/zips/$$*.zip'
	@$$(BINODEPS_REAL_HOME)/share/binodeps/dirzip \
	  --array CD $$(words $$(CD)) $$(CD:%='%') \
	  --array ZIP $$(words $$(ZIP)) $$(ZIP:%='%') \
	  --out='$$(BINODEPS_TMPDIR)/python$1/zips/$$*.zip' \
	  --dir='$$(BINODEPS_TMPDIR)/python$1/src/$$*' -qr -- \
	  $$(pyfiles_$$*:%=%.py) $$($$*_pyproto:%=%_pb2.py) \
	  $$(pyfiles_$$*:%=%.pyc) $$($$*_pyproto:%=%_pb2.pyc)
	@$$(MKDIR) '$$(@D)'
	@$$(MV) '$$(BINODEPS_TMPDIR)/python$1/zips/$$*.zip' '$$@'

endef

$(foreach V,$(PYTHON_VERSIONS),$(eval $(call PYTHON_VDEPS,$V)))
