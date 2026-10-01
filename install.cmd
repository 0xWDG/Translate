#!/bin/sh

swift build -c release
install -m 755 .build/release/translate /usr/local/bin/translate
