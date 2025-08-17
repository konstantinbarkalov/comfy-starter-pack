# Comfy Starter Pack

A simple and secure script to download a curated list of models (checkpoints, LoRAs, VAEs, etc.) for ComfyUI or any Stable Diffusion setup.

This project separates the model list from your private API keys, so you can safely manage your model collection in a public repository.

---

## Prerequisites

Before you start, make sure you have these tools installed:
* `git`
* `jq`
* `wget`
* `curl`

On a Debian/Ubuntu system, you can install them all with:
```sh
sudo apt-get update && sudo apt-get install -y git jq wget curl
Note: The script uses curl to efficiently query the Civitai API and wget to download the large model files, as it provides a clear progress bar.🚀 Quickstart Guide1. Get the FilesClone the repository to your machine:git clone [https://github.com/konstantinbarkalov/comfy-starter-pack.git](https://github.com/konstantinbarkalov/comfy-starter-pack.git)
cd comfy-starter-pack
2. Add Your API KeysRun the add_secrets.sh script to create your private secrets.json file. This file is already in .gitignore and will not be uploaded to GitHub../add_secrets.sh --civit "YOUR_CIVITAI_KEY" --hf "YOUR_HUGGINGFACE_KEY"
3. Start DownloadingRun the main script. It will read models.json and download everything to the specified directories../download_models.sh
The script will automatically skip any files that you have already downloaded.✏️ Understanding models.jsonAll customization happens in the models.json file. It has two main sections: directories and models.The directories SectionThis part defines the folder structure for your downloads."base": This is the main root folder where all model subdirectories will be created."checkpoint", "lora", "vae", "controlnet": These keys define the subfolder for each model type. The script combines the "base" path with the value of these keys. For example, a model with "type": "lora" will be saved in the base + loras folder."directories": {
  "base": "/workspace/ComfyUI/models",
  "checkpoint": "checkpoints",
  "lora": "loras",
  "controlnet": "controlnet",
  "vae": "vae"
}
The models SectionThis is a list where each entry is an object representing one model to download. Each model object must have three keys:"url": The link to the model.For Civitai, use the main model page URL (e.g., https://civitai.com/models/12345). The script will automatically find the latest version.For Hugging Face, use the direct link to the file, which must contain /resolve/ or /blob/ in the path."type": This tells the script where to save the file. It must match one of the singular keys from the directories section (e.g., "checkpoint", "lora")."filename": The exact name for the downloaded file, including the extension (e.g., .safetensors, .ckpt).Example Entry:{
  "url": "[https://civitai.com/models/112253](https://civitai.com/models/112253)",
  "type": "checkpoint",
  "filename": "urban_realistic.safetensors"
}
