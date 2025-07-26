import os
from PIL import Image, ImageDraw, ImageFont

# Create directory for app icons
output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../nutribase/Assets.xcassets/AppIcon.appiconset")
os.makedirs(output_dir, exist_ok=True)

# Define icon sizes needed for iOS
icon_sizes = {
    # iPhone
    "iphone-notification-20pt@2x.png": (40, 40),
    "iphone-notification-20pt@3x.png": (60, 60),
    "iphone-settings-29pt@2x.png": (58, 58),
    "iphone-settings-29pt@3x.png": (87, 87),
    "iphone-spotlight-40pt@2x.png": (80, 80),
    "iphone-spotlight-40pt@3x.png": (120, 120),
    "iphone-app-60pt@2x.png": (120, 120),
    "iphone-app-60pt@3x.png": (180, 180),
    
    # iPad
    "ipad-notifications-20pt.png": (20, 20),
    "ipad-notifications-20pt@2x.png": (40, 40),
    "ipad-settings-29pt.png": (29, 29),
    "ipad-settings-29pt@2x.png": (58, 58),
    "ipad-spotlight-40pt.png": (40, 40),
    "ipad-spotlight-40pt@2x.png": (80, 80),
    "ipad-app-76pt.png": (76, 76),
    "ipad-app-76pt@2x.png": (152, 152),
    "ipad-pro-app-83.5pt@2x.png": (167, 167),
    
    # App Store
    "app-store-1024pt.png": (1024, 1024)
}

def create_nutribase_icon(size):
    """Create a simple NutriBase app icon with the specified size"""
    # Create a new image with a green background
    img = Image.new('RGB', size, color=(46, 204, 113))
    draw = ImageDraw.Draw(img)
    
    # Calculate dimensions
    width, height = size
    center_x, center_y = width // 2, height // 2
    radius = min(width, height) // 3
    
    # Draw a white circle in the center
    draw.ellipse(
        (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
        fill=(255, 255, 255)
    )
    
    # Draw a leaf shape
    leaf_points = [
        (center_x, center_y - radius // 2),
        (center_x + radius // 2, center_y),
        (center_x, center_y + radius // 2),
        (center_x - radius // 2, center_y)
    ]
    draw.polygon(leaf_points, fill=(46, 204, 113))
    
    # Add "N" text if the icon is large enough
    if min(width, height) >= 76:
        # Try to load a font
        try:
            font_size = width // 4
            font = ImageFont.truetype("Arial.ttf", font_size)
            text = "N"
            text_width, text_height = draw.textsize(text, font=font)
            draw.text(
                (center_x - text_width // 2, center_y - text_height // 2),
                text,
                fill=(46, 204, 113),
                font=font
            )
        except:
            # If font loading fails, just continue without text
            pass
    
    return img

# Generate all required icon sizes
for icon_name, size in icon_sizes.items():
    icon = create_nutribase_icon(size)
    icon_path = os.path.join(output_dir, icon_name)
    icon.save(icon_path)
    print(f"Generated {icon_name} ({size[0]}x{size[1]})")

print("\nAll app icons generated successfully!")
print(f"Icons saved to: {output_dir}")
