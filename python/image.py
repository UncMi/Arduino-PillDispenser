import os
import json
import asyncio
from aiohttp import ClientSession
from PIL import Image
import requests
from io import BytesIO
from flask import Flask, request, jsonify, send_from_directory
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.pyplot as plt



UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)


loaded_image_np = np.load(os.path.join(UPLOAD_FOLDER, "concatenated_image.npy"))
image_np = loaded_image_np.squeeze(axis=0)

plt.imshow(image_np)
plt.axis('off')  # Turn off axis
plt.show()