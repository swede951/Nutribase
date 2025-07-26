import os
import sys
from PIL import Image

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

def process_icon(source_image_path):
    """Process the source image and create all required app icon sizes"""
    try:
        # Open the source image
        img = Image.open(source_image_path)
        
        # Generate all required icon sizes
        for icon_name, size in icon_sizes.items():
            # Create a copy of the image and resize it
            resized_img = img.copy()
            resized_img = resized_img.resize(size, Image.LANCZOS)
            
            # Save the resized image
            icon_path = os.path.join(output_dir, icon_name)
            resized_img.save(icon_path)
            print(f"Generated {icon_name} ({size[0]}x{size[1]})") 
        
        print("\nAll app icons generated successfully!")
        print(f"Icons saved to: {output_dir}")
        return True
    except Exception as e:
        print(f"Error processing icon: {e}")
        return False

if __name__ == "__main__":
    # Use the image from Documents folder
    source_image_path = os.path.expanduser("~/Documents/app icon.png")
    
    if not os.path.exists(source_image_path):
        print(f"Error: Could not find the app icon at {source_image_path}")
        sys.exit(1)
    
    # Process the icon
    print(f"Using app icon from: {source_image_path}")
    success = process_icon(source_image_path)
    if not success:
        sys.exit(1)
