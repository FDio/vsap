# Copyright (c) 2020 Intel and/or its affiliates.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifneq ($(shell uname),Darwin)
	OS_ID        := $(shell grep '^ID=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g')
	OS_VERSION_ID:= $(shell grep '^VERSION_ID=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g')
else
	$(warning exit)
	@exit 1;
endif

# Scripts require non-POSIX parts of bash
SHELL := /bin/bash

export BR=$(CURDIR)

DL_CACHE_DIR = $(CURDIR)/downloads
vpp ?= master
MAKE ?= make
MAKE_ARGS ?= -j
openssl3_enable ?= 0
openssl3_lib_ready ?= 0
debug ?= 0
BUILD_DIR        ?= $(CURDIR)/_build
INSTALL_DIR      ?= $(CURDIR)/_install

MAIN_BRANCH := master

B := $(BUILD_DIR)
I := $(INSTALL_DIR)

_VPP_VER := $(vpp)


LINUX_ITER := $(OS_ID)$(OS_VERSION_ID)
LICENSE := BSD

.PHONY: help
help:
	@echo "Make Targets:"
	@echo " dep             - install software dependencies"
	@echo " deb-vcl         - build vcl DEB package"
	@echo " build-vcl       - build vcl vpp and vcl nginx"
	@echo " deb-ldp         - build ldp DEB package"
	@echo " build-ldp       - build ldp vpp and ldp nginx"
	@echo " verify-vcl      - verify vcl starts properly"
	@echo " verify-ldp      - verify ldp starts properly"
	@echo " clean           - clean up build environment."
	@echo " clean-vcl       - clean up build vcl environment."
	@echo " clean-ldp       - clean up build ldp environment."
	@echo "Make Arguments:"
	@echo " debug           - 1:make build, 0:make build-release"
	@echo " openssl3_enable - 1:support openssl3"
	@echo ""

include packages/packages.mk
include packages/package.mk
include packages/openssl-dl.mk
include packages/nginx-dl.mk
include packages/openssl.mk
include packages/vpp_vcl.mk
include packages/vpp_ldp.mk
include packages/nginx_vcl.mk
include packages/nginx_ldp.mk

.PHONY: clean
clean:
	@rm -rf $(B) $(I)

.PHONY: clean-vcl
clean-vcl:
	@rm -f $(B)/.*vcl*

.PHONY: clean-ldp
clean-ldp:
	@rm -f $(B)/.*ldp*

$(BR)/.deps.ok:
	make dep
	@touch $@

.PHONY: build-vcl
ifeq ($(openssl3_enable)_$(openssl3_lib_ready), 1_1)
build-vcl: $(BR)/.deps.ok nginx-dl vpp_vcl-build nginx_vcl-build
else ifeq ($(openssl3_enable),1)
build-vcl: $(BR)/.deps.ok openssl-dl nginx-dl openssl-build vpp_vcl-build nginx_vcl-build
else
build-vcl: $(BR)/.deps.ok nginx-dl vpp_vcl-build nginx_vcl-build
endif

.PHONY: build-ldp
ifeq ($(openssl3_enable)_$(openssl3_lib_ready), 1_1)
build-ldp: $(BR)/.deps.ok nginx-dl vpp_ldp-build nginx_ldp-build
else ifeq ($(openssl3_enable),1)
build-ldp: $(BR)/.deps.ok openssl-dl nginx-dl openssl-build vpp_ldp-build nginx_ldp-build
else
build-ldp: $(BR)/.deps.ok nginx-dl vpp_ldp-build nginx_ldp-build
endif

.PHONY: deb-vcl
ifeq ($(openssl3_enable)_$(openssl3_lib_ready), 1_1)
deb-vcl: build-vcl vpp_vcl-deb nginx_vcl-deb
else ifeq ($(openssl3_enable),1)
deb-vcl: build-vcl openssl-deb vpp_vcl-deb nginx_vcl-deb
else
deb-vcl: build-vcl vpp_vcl-deb nginx_vcl-deb
endif

.PHONY: deb-ldp
ifeq ($(openssl3_enable)_$(openssl3_lib_ready), 1_1)
deb-ldp: build-ldp vpp_ldp-deb nginx_ldp-deb
else ifeq ($(openssl3_enable),1)
deb-ldp: build-ldp openssl-deb vpp_ldp-deb nginx_ldp-deb
else
deb-ldp: build-ldp vpp_ldp-deb nginx_ldp-deb
endif

.PHONY: verify-vcl
verify-vcl: build-vcl
	@./packages/verify.sh vcl

.PHONY: verify-ldp
verify-ldp: build-ldp
	@./packages/verify.sh ldp

.PHONY: dep
dep:
ifeq ($(OS_ID),ubuntu)
	@sudo -E apt-get update
	@sudo -E apt-get install git gcc make \
		ruby ruby-dev libpam0g-dev \
		libmariadb-client-lgpl-dev \
		libmysqlclient-dev -y
	@sudo -E gem install fpm
	@cd vpp; echo yes|make install-dep;
endif
