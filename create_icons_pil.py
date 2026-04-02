#!/usr/bin/env python3
"""
Create professional and fun icons for Kinetic app
"""
from PIL import Image, ImageDraw
import os

def create_parent_icon(output_path: str, size: int):
    """Create modern professional icon for parent app - simple K with blue gradient"""
    # Create image with blue gradient
    img = Image.new('RGB', (size, size), color='#2563EB')
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Draw gradient (blue to darker blue)
    for i in range(size):
        # Interpolate color from lighter to darker blue
        ratio = i / size
        r = int(59 * (1 - ratio) + 37 * ratio)    # 3B to 25
        g = int(130 * (1 - ratio) + 99 * ratio)   # 82 to 63
        b = int(246 * (1 - ratio) + 235 * ratio)  # F6 to EB
        draw.line([(0, i), (size, i)], fill=(r, g, b))
    
    # Draw large white "K" text
    k_x = size // 2
    k_y = size // 2
    half_height = int(size * 0.25)
    
    # Draw K manually using lines for consistent appearance
    line_width = max(2, int(size * 0.11))
    
    # Vertical line of K (left side)
    vertical_x = k_x - int(size * 0.15)
    draw.line(
        [(vertical_x, k_y - half_height), 
         (vertical_x, k_y + half_height)],
        fill=(255, 255, 255),
        width=line_width
    )
    
    # Top diagonal of K (from middle right to upper left)
    draw.line(
        [(k_x + int(size * 0.18), k_y - int(size * 0.18)),
         (vertical_x, k_y)],
        fill=(255, 255, 255),
        width=line_width
    )
    
    # Bottom diagonal of K (from middle left to lower right)
    draw.line(
        [(vertical_x, k_y),
         (k_x + int(size * 0.18), k_y + int(size * 0.18))],
        fill=(255, 255, 255),
        width=line_width
    )
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, 'PNG')
    print(f"✓ Created {output_path} ({size}x{size})")

def create_kids_icon(output_path: str, size: int):
    """Create fun/gamified icon for kids app - simple K with orange-pink gradient"""
    # Create image with orange gradient background
    img = Image.new('RGB', (size, size), color='#F97316')
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Draw gradient (orange to pink)
    for i in range(size):
        # Interpolate color from orange to pink
        ratio = i / size
        r = int(249 * (1 - ratio) + 236 * ratio)  # F9 to EC
        g = int(115 * (1 - ratio) + 72 * ratio)   # 73 to 48
        b = int(22 * (1 - ratio) + 153 * ratio)   # 16 to 99
        draw.line([(0, i), (size, i)], fill=(r, g, b))
    
    # Draw large white "K" text
    k_x = size // 2
    k_y = size // 2
    half_height = int(size * 0.25)
    
    # Draw K manually using lines for consistent appearance
    line_width = max(2, int(size * 0.11))
    
    # Vertical line of K (left side)
    vertical_x = k_x - int(size * 0.15)
    draw.line(
        [(vertical_x, k_y - half_height), 
         (vertical_x, k_y + half_height)],
        fill=(255, 255, 255),
        width=line_width
    )
    
    # Top diagonal of K (from middle right to upper left)
    draw.line(
        [(k_x + int(size * 0.18), k_y - int(size * 0.18)),
         (vertical_x, k_y)],
        fill=(255, 255, 255),
        width=line_width
    )
    
    # Bottom diagonal of K (from middle left to lower right)
    draw.line(
        [(vertical_x, k_y),
         (k_x + int(size * 0.18), k_y + int(size * 0.18))],
        fill=(255, 255, 255),
        width=line_width
    )
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, 'PNG')
    print(f"✓ Created {output_path} ({size}x{size})")

def main():
    print("Creating app icons using PIL/Pillow...\n")
    
    # Parent app icons
    print("PARENT APP - Professional Icon:")
    parent_sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }
    
    for dpi, size in parent_sizes.items():
        output = rf'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\android\app\src\main\res\mipmap-{dpi}\ic_launcher.png'
        create_parent_icon(output, size)
    
    # iOS icon for parent
    create_parent_icon(
        r'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\parent\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png',
        180
    )
    
    # Kids app icons
    print("\nKIDS APP - Fun/Gamified Icon:")
    kids_sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }
    
    for dpi, size in kids_sizes.items():
        output = rf'c:\Users\Ingmar\Documents\Projects\Kinetic\apps\kids\android\app\src\main\res\mipmap-{dpi}\ic_launcher.png'
        create_kids_icon(output, size)
    
    print("\n" + "="*50)
    print("Icon creation complete!")
    print("="*50)

if __name__ == '__main__':
    main()
