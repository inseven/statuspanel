#!/bin/bash

{ gittyleaks --no-fancy-color 2>&1; } | grep -v ".*\.storyboard:"
