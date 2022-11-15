#!/bin/bash
# https://github.com/roylez/huginn/commit/55eac40d1c27d68aa7fad4bb755281a9bc044d49
set -eux

rm -rf vendor/bundle/ruby/3.2.0/cache/*.gem && \
find vendor/bundle/ruby/3.2.0/gems/ -name "*.c" -delete && \
find vendor/bundle/ruby/3.2.0/gems/ -name "*.o" -delete && \
rm -rf vendor/bundle/ruby/3.2.0/gems/grpc-*/include && \
rm -rf vendor/bundle/ruby/3.2.0/gems/grpc-*/third_party && \
rm -rf vendor/bundle/ruby/3.2.0/gems/grpc-*/src/core && \
rm -rf vendor/bundle/ruby/3.2.0/gems/grpc-*/src/ruby/ext
