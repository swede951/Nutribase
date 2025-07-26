import os
from PIL import Image, ImageDraw

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
    """Create a NutriBase app icon with the specified size"""
    # Create a new image with a peach background
    img = Image.new('RGB', size, color=(255, 222, 189))
    draw = ImageDraw.Draw(img)
    
    # Calculate dimensions
    width, height = size
    center_x, center_y = width // 2, height // 2
    scale_factor = min(width, height) / 1024  # Scale based on 1024px reference
    
    # Draw a fork and scale icon (simplified version)
    # Draw the fork handle
    handle_width = int(100 * scale_factor)
    handle_height = int(500 * scale_factor)
    handle_x = center_x - handle_width // 2
    handle_y = center_y
    draw.rectangle((handle_x, handle_y, handle_x + handle_width, handle_y + handle_height), 
                  fill=(220, 220, 220), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    # Draw the fork prongs
    prong_width = int(40 * scale_factor)
    prong_height = int(300 * scale_factor)
    prong_spacing = int(20 * scale_factor)
    prong_y = center_y - prong_height
    
    for i in range(4):
        prong_x = handle_x - int(60 * scale_factor) + i * (prong_width + prong_spacing)
        draw.rectangle((prong_x, prong_y, prong_x + prong_width, center_y), 
                      fill=(220, 220, 220), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    # Draw the knife/scale beam
    beam_width = int(500 * scale_factor)
    beam_height = int(60 * scale_factor)
    beam_y = center_y - beam_height // 2
    draw.rectangle((center_x - beam_width // 2, beam_y, center_x + beam_width // 2, beam_y + beam_height), 
                  fill=(220, 220, 220), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    # Draw the left scale bowl (orange)
    bowl_radius = int(100 * scale_factor)
    left_bowl_x = center_x - int(200 * scale_factor)
    left_bowl_y = center_y + int(200 * scale_factor)
    draw.ellipse((left_bowl_x - bowl_radius, left_bowl_y - bowl_radius // 2, 
                 left_bowl_x + bowl_radius, left_bowl_y + bowl_radius // 2), 
                fill=(255, 180, 100), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    # Draw the right scale bowl (green)
    right_bowl_x = center_x + int(200 * scale_factor)
    right_bowl_y = center_y + int(200 * scale_factor)
    draw.ellipse((right_bowl_x - bowl_radius, right_bowl_y - bowl_radius // 2, 
                 right_bowl_x + bowl_radius, right_bowl_y + bowl_radius // 2), 
                fill=(180, 230, 180), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    # Draw the scale strings
    draw.line((left_bowl_x, beam_y + beam_height // 2, left_bowl_x, left_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    draw.line((right_bowl_x, beam_y + beam_height // 2, right_bowl_x, right_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    
    # Draw diagonal support lines
    draw.line((left_bowl_x - bowl_radius // 2, beam_y + beam_height // 2, left_bowl_x, left_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    draw.line((left_bowl_x + bowl_radius // 2, beam_y + beam_height // 2, left_bowl_x, left_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    
    draw.line((right_bowl_x - bowl_radius // 2, beam_y + beam_height // 2, right_bowl_x, right_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    draw.line((right_bowl_x + bowl_radius // 2, beam_y + beam_height // 2, right_bowl_x, right_bowl_y - bowl_radius // 4), 
             fill=(80, 80, 80), width=max(1, int(8 * scale_factor)))
    
    # Add a red accent to the knife part
    knife_width = int(150 * scale_factor)
    draw.rectangle((center_x, beam_y, center_x + knife_width, beam_y + beam_height), 
                  fill=(255, 150, 130), outline=(80, 80, 80), width=max(1, int(10 * scale_factor)))
    
    return img

# Generate all required icon sizes
for icon_name, size in icon_sizes.items():
    icon = create_nutribase_icon(size)
    icon_path = os.path.join(output_dir, icon_name)
    icon.save(icon_path)
    print(f"Generated {icon_name} ({size[0]}x{size[1]})")

print("\nAll app icons generated successfully!")
print(f"Icons saved to: {output_dir}")
