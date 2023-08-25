#!/bin/bash

VERSION=$1

pwsh Update-LibraryCredits.ps1 NabuNet

dotnet publish NabuNet --self-contained --runtime linux-x64 -o tmp -p version="$VERSION" -c Release


