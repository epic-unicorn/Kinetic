#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

# Define conversion sizes for Android and iOS
conversions = {
    # Parent/Partner app with professional icon
    'parent': {
        'svg': r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\assets\icon_partner.svg',
        'android': {
            'mdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-mdpi\ic_launcher.png', 48),
            'hdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-hdpi\ic_launcher.png', 72),
            'xhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png', 96),
            'xxhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png', 144),
            'xxxhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png', 192),
        },
        'ios': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png', 180),
    },
    # Kids app with fun/gamified icon
    'kids': {
        'svg': r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\assets\icon_kids.svg',
        'android': {
            'mdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-mdpi\ic_launcher.png', 48),
            'hdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-hdpi\ic_launcher.png', 72),
            'xhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png', 96),
            'xxhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png', 144),
            'xxxhdpi': (r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png', 192),
        },
    },
}

def convert_svg_to_png(svg_path, output_path, width, height):
    """Convert SVG to PNG using cairosvg"""
    import cairosvg
    output_dir = os.path.dirname(output_path)
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        cairosvg.svg2png(
            url=svg_path,
            write_to=output_path,
            output_width=width,
            output_height=height
        )
        print(f"✓ Created {output_path} ({width}x{height})")
        return True
    except Exception as e:
        print(f"✗ Failed to create {output_path}: {e}")
        return False

def main():
    print("Converting SVG icons to PNG...\n")
    
    success_count = 0
    fail_count = 0
    
    for app_name, config in conversions.items():
        svg_path = config['svg']
        print(f"\n{app_name.upper()} APP:")
        
        if not os.path.exists(svg_path):
            print(f"  ✗ SVG file not found: {svg_path}")
            continue
        
        print(f"  Converting Android icons...")
        for dpi, (output_path, size) in config['android'].items():
            if convert_svg_to_png(svg_path, output_path, size, size):
                success_count += 1
            else:
                fail_count += 1
        
        # iOS icon (only for parent app which has iOS)
        if 'ios' in config and config['ios']:
            ios_path, ios_size = config['ios']
            print(f"  Converting iOS icon...")
            if convert_svg_to_png(svg_path, ios_path, ios_size, ios_size):
                success_count += 1
            else:
                fail_count += 1
    
    print(f"\n{'='*50}")
    print(f"Conversion complete: {success_count} succeeded, {fail_count} failed")
    print(f"{'='*50}")

if __name__ == '__main__':
    main()
