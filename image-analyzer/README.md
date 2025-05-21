# Azure AI Tree Image Pipeline

This repository provides a pipeline to upload, analyze, sort, and download images using Azure Blob Storage and Azure AI. The pipeline is designed to detect trees (or any keyword you specify) in your images using Azure Computer Vision.

## Features
- **Upload**: Upload local images to Azure Blob Storage.
- **Clean**: Remove all blobs from the container except those in the `tree-pictures/` folder.
- **Analyze**: Use Azure AI to detect trees (or your chosen keywords) in images and move them to the `tree-pictures/` folder.
- **Download**: Download all images/videos from the `tree-pictures/` folder to your local machine.

## Requirements
- Python 3.8+
- Azure credentials in a `.env` file:
  - `BLOB_CONNECTION_STRING`
  - `BLOB_CONTAINER`
  - `AZURE_COMPUTER_VISION_KEY`
  - `AZURE_COMPUTER_VISION_ENDPOINT`
- Install dependencies:
  ```bash
  pip install -r requirements.txt
  ```

## Usage

```bash
python tree_image_pipeline.py --upload ./local_images
python tree_image_pipeline.py --clean
python tree_image_pipeline.py --analyze --keywords tree oak pine
python tree_image_pipeline.py --download ./downloaded_tree_media
```

You can combine options as needed. For example, to upload, analyze, and download in one go:

```bash
python tree_image_pipeline.py --upload ./local_images --analyze --download ./downloaded_tree_media
```

## Environment Setup

- Copy `.env.template` to `.env` and fill in your Azure credentials and settings:
  ```bash
  cp .env.template .env
  # Edit .env with your values
  ```
- The `.env` file is gitignored for your security. Share `.env.template` for onboarding.

## .gitignore

- This repo ignores `__pycache__/`, `*.pyc`, and `.env` for a clean and secure version control history.

## Testing

Basic tests are provided using `pytest`:

```bash
pytest test_tree_image_pipeline.py
```

> **Note:** For real Azure integration, you should mock Azure services or use a test container.

## License
MIT
