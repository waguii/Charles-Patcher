#!/bin/bash

# Title: Charles Patcher
# Define the path to charles.jar
CHARLES_PATH="/usr/lib/charles-proxy/charles.jar"
IDENTIFICATION="Charles Patcher"

# Go to script directory
cd "$(dirname "$0")"
export PATH="$PATH:$(pwd)/jdk/bin:$(pwd)/grep"

# Preparing
echo "Cleaning files..."
rm -rf ./charles/ 2>/dev/null
rm -f ./Main.jad ./grep.temp *.java 2>/dev/null
rm -rf ./com/ 2>/dev/null
rm -f ./charles*.jar 2>/dev/null
sleep 1

cp "$CHARLES_PATH" ./charles_original.jar 2>/dev/null && echo "Copied charles.jar to charles_original.jar"

# Extract charles.jar
echo "Extracting charles.jar..."
mkdir ./charles/
cd ./charles/
jar xf ../charles_original.jar
if [[ $? -ne 0 ]]; then
    echo "Failed to extract charles.jar"
    exit 1
fi
cd ..

# Decompiling
echo "Decompiling Main.class..."
java -jar cfr-0.150.jar ./charles/com/xk72/charles/Main.class > Main.cfr 2>&1
if [[ $? -ne 0 ]]; then
    echo "Failed to decompile Main.class"
    exit 1
fi
echo "Decompilation complete. Checking content..."

# Diagnostic: Print some content of the decompiled file
head -n 20 Main.cfr

grep "protected boolean [a-zA-Z]" Main.cfr | grep -Eo -m 1 " [a-zA-Z]+;" | grep -Eo -m 1 "[a-zA-Z]+" > grep.temp
VALIDATE=$(<grep.temp)
echo "VALIDATE method: $VALIDATE"

grep "Registered to: " Main.cfr | grep -Eo "[a-zA-Z]+\.[a-zA-Z]+\(\)" | grep -Eo "[a-zA-Z]+\." | grep -Eo "[a-zA-Z]+" > grep.temp
CLASS=$(<grep.temp)
echo "CLASS name: $CLASS"

grep "Registered to: " Main.cfr | grep -Eo "[a-zA-Z]+\.[a-zA-Z]+\(\)" | grep -Eo "\.[a-zA-Z]+" | grep -Eo "[a-zA-Z]+" > grep.temp
IDENTIFY=$(<grep.temp)
echo "IDENTIFY method: $IDENTIFY"

# Check results
if [[ -z $VALIDATE || -z $CLASS || -z $IDENTIFY ]]; then
    echo "Error: Failed to extract expected identifiers."
    exit 1
fi

# Patching
echo "Patching $CLASS.java..."
cat << EOF > $CLASS.java
package com.xk72.charles;
public final class $CLASS {
    public static boolean $VALIDATE() { return true; }
    public static String $IDENTIFY() { return "$IDENTIFICATION"; }
    public static String $VALIDATE(String name, String key) { return null; }
}
EOF

javac -encoding UTF-8 $CLASS.java -d .
if [[ $? -ne 0 ]]; then
    echo "Failed to compile $CLASS.java"
    exit 1
fi

cp ./charles_original.jar ./charles.jar
jar -uvf ./charles.jar ./com/xk72/charles/$CLASS.class 2>/dev/null
if [[ $? -ne 0 ]]; then
    echo "Failed to update charles.jar with compiled class."
    exit 1
fi
cp ./charles.jar "$CHARLES_PATH"

# Cleaning
echo "Cleaning files..."
rm -rf ./charles/ 2>/dev/null
rm -f ./Main.jad grep.temp *.java 2>/dev/null
rm -rf ./com/ 2>/dev/null
sleep 1

echo
echo "Done!"
echo
