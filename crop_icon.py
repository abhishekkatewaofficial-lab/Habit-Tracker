import sys
from PIL import Image, ImageChops

def trim(im):
    # Get the background color of the top-left corner
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    # Since it's a JPEG, use a threshold to handle compression artifacts
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im

try:
    img_path = "/Users/hemlata/.gemini/antigravity/brain/90f36ad5-0b8a-4d84-aac5-004b492558e4/media__1775300211507.jpg"
    img = Image.open(img_path).convert('RGB')
    cropped = trim(img)
    # Save it as the new app icon png
    out_path = "assets/app_icon.png"
    # Ensure cropped is square
    width, height = cropped.size
    size = max(width, height)
    # Create square background
    # Since we want a transparent icon or white icon? The user said "remove extra blue background by cropping"
    # The squircle is white. Let's just make it square.
    new_img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    new_img.paste(cropped, ((size - width) // 2, (size - height) // 2))
    
    new_img.save(out_path, "PNG")
    print(f"Successfully cropped icon and saved to {out_path} with size {size}x{size}")
except Exception as e:
    print(f"Error: {e}")
