import os
import sys
import requests
import time
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from msrest.authentication import CognitiveServicesCredentials
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Azure Computer Vision configuration
subscription_key = os.environ.get("AZURE_COMPUTER_VISION_KEY")
endpoint = os.environ.get("AZURE_COMPUTER_VISION_ENDPOINT")

# Initialize Azure Computer Vision client
if not subscription_key or not endpoint:
    print("Error: Azure Computer Vision credentials not found in environment variables")
    print("Please check your .env file")
    sys.exit(1)

vision_client = ComputerVisionClient(endpoint, CognitiveServicesCredentials(subscription_key))

def analyze_image(image_url, search_term=None):
    """Analyze image using Azure Computer Vision and detect if it contains the search term from .env if not provided."""
    if search_term is None or search_term == "":
        search_term = os.environ.get("KEYWORD", "tree")
    try:
        print(f"Analyzing image: {image_url}")
        analysis = vision_client.analyze_image(
            image_url,
            visual_features=["Tags", "Objects", "Description"]
        )
        tags = [tag.name.lower() for tag in analysis.tags]
        if search_term.lower() in tags:
            print(f"✓ Found '{search_term}' in image tags!")
            return True
        if analysis.objects:
            objects = [obj.object_property.lower() for obj in analysis.objects]
            if search_term.lower() in objects:
                print(f"✓ Found '{search_term}' in image objects!")
                return True
        if analysis.description and analysis.description.captions:
            captions = [caption.text.lower() for caption in analysis.description.captions]
            for caption in captions:
                if search_term.lower() in caption:
                    print(f"✓ Found '{search_term}' in image description!")
                    return True
        print(f"✗ Did not find '{search_term}' in image analysis")
        return False
    except Exception as e:
        print(f"Error analyzing image {image_url}: {e}")
        return False

def analyze_image_file(image_path, search_term="jeans"):
    """Analyze a local image file using Azure Computer Vision and detect if it contains the search term"""
    try:
        print(f"Analyzing local image: {image_path}")
        with open(image_path, "rb") as image_stream:
            analysis = vision_client.analyze_image_in_stream(
                image_stream,
                visual_features=["Tags", "Objects", "Description"]
            )
        tags = [tag.name.lower() for tag in analysis.tags]
        if search_term.lower() in tags:
            print(f"✓ Found '{search_term}' in image tags!")
            return tags
        if analysis.objects:
            objects = [obj.object_property.lower() for obj in analysis.objects]
            if search_term.lower() in objects:
                print(f"✓ Found '{search_term}' in image objects!")
                return tags
        if analysis.description and analysis.description.captions:
            captions = [caption.text.lower() for caption in analysis.description.captions]
            for caption in captions:
                if search_term.lower() in caption:
                    print(f"✓ Found '{search_term}' in image description!")
                    return tags
        print(f"✗ Did not find '{search_term}' in image analysis")
        return tags
    except Exception as e:
        print(f"Error analyzing local image {image_path}: {e}")
        return []

def download_image(image_url, destination_folder, filename):
    os.makedirs(destination_folder, exist_ok=True)
    try:
        response = requests.get(image_url, stream=True)
        if response.status_code == 200:
            file_path = os.path.join(destination_folder, filename)
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(1024):
                    f.write(chunk)
            print(f"Downloaded: {file_path}")
            return True
        else:
            print(f"Failed to download {image_url}, status code: {response.status_code}")
            return False
    except Exception as e:
        print(f"Error downloading {image_url}: {e}")
        return False

def test_vision_api():
    sample_image_url = "https://raw.githubusercontent.com/Azure-Samples/cognitive-services-sample-data-files/master/ComputerVision/Images/objects.jpg"
    print("Testing Azure Computer Vision API with a sample image...")
    try:
        result = analyze_image(sample_image_url, "laptop")
        if result:
            print("✓ API test successful! The sample image contains a laptop.")
        else:
            print("API test completed, but the sample image doesn't contain the expected content.")
        return True
    except Exception as e:
        print(f"❌ API test failed: {e}")
        print("Please check your Azure credentials and network connection.")
        return False

if __name__ == "__main__":
    print("Azure Computer Vision Image Analyzer")
    print("====================================")
    if test_vision_api():
        print("\nAPI is working correctly! You can now use this tool to analyze images.")
        print("Usage examples:")
        print("  python image_analyzer.py analyze https://example.com/image.jpg jeans")
        print("  python image_analyzer.py download https://example.com/image.jpg ./downloads image.jpg")
    else:
        print("\nAPI test failed. Please check your Azure credentials and try again.")
