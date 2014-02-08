#!/bin/bash

mkdir ../dist &>/dev/null
mkdir ../build &>/dev/null

java -jar compiler.jar --compilation_level WHITESPACE_ONLY --formatting PRETTY_PRINT --js ../src/hmac-sha1.js --js ../src/N.js --js ../src/N.Base64.js --js ../src/N.API.js --js_output_file ../build/nuve.js

./compileDist.sh
