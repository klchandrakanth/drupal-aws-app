#!/usr/bin/env python3
"""
Script to generate buildspec.yml from template
"""
import shutil
import os
import sys

def generate_buildspec():
    """Generate buildspec.yml from template"""

    try:
        # Copy the template to buildspec.yml
        shutil.copy('buildspec-template.yml', 'buildspec.yml')
        print("Generated buildspec.yml from template")
        print("✓ File generation successful")
    except Exception as e:
        print(f"✗ File generation failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    generate_buildspec()