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
```

🚀 Quickstart Guide
1. Get the Files

Clone the repository to your machine:

git clone [https://github.com/konstantinbarkalov/comfy-starter-pack.git](https://github.com/konstantinbarkalov/comfy-starter-pack.git)
cd comfy-starter-pack

2. Add Your API Keys

Run the add_secrets.sh script to create your private secrets.json file. This file is already in .gitignore and will not be uploaded to GitHub.

./add_secrets.sh --civit "YOUR_CIVITAI_KEY" --hf "YOUR_HUGGINGFACE_KEY"

3. Start Downloading

Run the main script. It will read models.json and download everything to the specified directories.

./download_models.sh

The script will automatically skip any files that you have already downloaded.

✏️ Customizing the Model List
To add, remove, or change models, you only need to edit the models.json file.

Add a model: Add a new block to the models list.

Set the type: Use "checkpoint", "lora", "vae", or "controlnet" to save it to the correct folder.

Set the filename: Choose a clean name for the downloaded file.

{
  "url": "[https://civitai.com/models/](https://civitai.com/models/)...",
  "type": "lora",
  "filename": "my_favorite_lora.safetensors"
}
