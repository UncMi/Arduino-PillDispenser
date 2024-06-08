from io import BytesIO
import io
import os
import json
import asyncio
from aiohttp import ClientSession
from PIL import Image, UnidentifiedImageError
import numpy as np
import cv2
from quart import Quart, request, jsonify, send_from_directory
from quart_cors import cors
import requests

app = Quart(__name__)
app = cors(app)

current_directory = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(current_directory, 'uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

class_names = [
    '10150', '10151', '10250', '10251', '10270', '10271', '10280', '10281', '10290', '10291', '10410', 
    '10411', '10560', '10561', '10780', '10781', '11040', '11041', '11050', '11060', '11061', '11370', 
    '11640', '11641', '11650', '11651', '11660', '11661', '11670', '11671', '11680', '11681', '11690', 
    '11691', '12390', '12391', '12400', '12410', '12411', '12420', '12430', '12431', '12440', '5960', 
    '6670', '6700', '6751', '7350', '7351', '7360', '7370', '7371', '7440', '7441', '7480', '7481', '7490', 
    '7500', '7501', '7590', '7600', '7601', '7610', '7611', '7790', '7791', '8300', '8310', '8320', '8321', 
    '8330', '8331', '8600', '8601', '8610', '8620', '8621', '8630', '8640', '8650', '8651', '8661', '8670', 
    '8671', '8680', '8681', '8690', '8691', '8800', '8801', '8810', '8811', '8820', '8830', '8831', '8840', 
    '8841', '8850', '8851', '8860', '8861', '8870', '8880', '8890', '8891', '8900', '8901', '8910', '8911', 
    '8920', '8921', '8930', '8931', '8940', '8941', '8950', '8990', '8991', '9050', '9051', '9430', '9431', 
    '9440', '9441', '9450', '9451', '9630', '9640', '9641', '9650', '9651', '9660', '9670', '9750', '9870', 
    '9871', '9880', '9890', '9891', '9970'
]

concat_class_names = [
    '1015', '1025', '1027', '1028', '1029', '1041', '1056', '1078', '1104', '1105', '1106', '1137', '1164', 
    '1165', '1166', '1167', '1168', '1169', '1239', '1240', '1241', '1242', '1243', '1244', '596', '603', 
    '666', '667', '670', '671', '675', '693', '735', '736', '744', '748', '749', '750', '759', '760', '761', 
    '779', '830', '831', '832', '833', '860', '861', '862', '863', '864', '865', '866', '867', '868', '869', 
    '880', '881', '882', '883', '884', '885', '886', '887', '888', '889', '890', '891', '892', '893', '894', 
    '895', '899', '905', '943', '944', '945', '963', '964', '965', '966', '967', '975', '987', '988', '989', '997'
]


def img_decode(image):
    return cv2.imdecode(np.frombuffer(image, np.uint8), -1)

def split_images(image):
    try:
        pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    except Exception as e:
        print(f"Error converting image: {e}")
        return None, None

    width, height = pil_image.size

    img1 = pil_image.crop((0, 0, width // 2, height))
    img2 = pil_image.crop((width // 2, 0, width, height))

    return img1, img2




def pre_preprocess_image(image, img_width, filename):
    rotated_image = image.rotate(-90, expand=True)
    rotated_filename = 'rotated_' + filename
    rotated_filepath = os.path.join(UPLOAD_FOLDER, rotated_filename)
    rotated_image.save(rotated_filepath)

    min_dimension = min(rotated_image.width, rotated_image.height)
    left = (rotated_image.width - min_dimension) / 2
    top = (rotated_image.height - min_dimension) / 2
    right = left + min_dimension
    bottom = top + min_dimension
    cropped_rotated_image = rotated_image.crop((left, top, right, bottom))

    cropped_rotated_filename = 'cropped_rotated_' + filename
    cropped_rotated_filepath = os.path.join(UPLOAD_FOLDER, cropped_rotated_filename)
    cropped_rotated_image.save(cropped_rotated_filepath)

    resized_image = cropped_rotated_image.resize((img_width, img_width))

    reduced_quality_filepath = os.path.join(UPLOAD_FOLDER, f"reduced_quality_{filename}")
    reduced_quality_image = resized_image.copy()
    reduced_quality_image.save(reduced_quality_filepath, quality=90)

    return reduced_quality_image


def preprocess_image(image, output_filename):
    offset = 1
    param2Value = 110
    param2Change = 7

    image_np = np.array(image)
    image1 = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)
    image1 = cv2.blur(image1, (7, 7))
    orgGray = np.array(image1, copy=True)

    height, width = image_np.shape[:2]
    circles = None

    while (circles is None) and (param2Value > 50):
        image1 = np.array(orgGray, copy=True)
        circles = cv2.HoughCircles(image1, cv2.HOUGH_GRADIENT, 1, 40,
                                   param1=60, param2=param2Value, minRadius=0, maxRadius=0)
        param2Value -= param2Change

    if circles is not None:
        circles = np.uint16(np.around(circles))
        mask = np.zeros_like(image1)

        maxCircle = max(circles[0, :], key=lambda x: x[2])
        radius = int(maxCircle[2] * offset)
        cv2.circle(mask, (maxCircle[0], maxCircle[1]), radius, (255, 255, 255), thickness=-1)

        top = max(int(maxCircle[1] - radius), 0)
        bottom = min(int(maxCircle[1] + radius), height)
        left = max(int(maxCircle[0] - radius), 0)
        right = min(int(maxCircle[0] + radius), width)

        result = cv2.bitwise_and(image_np, image_np, mask=mask)
        isolated = result[top:bottom, left:right]

        if isolated.size == 0:
            return None

        isolated_resized = cv2.resize(isolated, (256, 256))
        output_path = os.path.join(UPLOAD_FOLDER, output_filename)
        cv2.imwrite(output_path, cv2.cvtColor(isolated_resized, cv2.COLOR_RGB2BGR))

        return isolated_resized
    else:
        return None

def concat_images(image1, image2):
    total_width = image1.width + image2.width
    max_height = max(image1.height, image2.height)

    new_img = Image.new('RGB', (total_width, max_height))
    new_img.paste(image1, (0, 0))
    new_img.paste(image2, (image1.width, 0))

    return new_img

async def send_to_model(image_np):
    data = json.dumps({"signature_name": "serving_default", "instances": image_np.tolist()})
    headers = {"content-type": "application/json"}
    async with ClientSession() as session:
        async with session.post('https://concat-model-latest.onrender.com/v1/models/concat_coin_model:predict', data=data, headers=headers) as response:
            return await response.json()

def img_encode(image):
    _, img_encoded = cv2.imencode('.jpg', image)
    return img_encoded.tobytes()








@app.route('/upload', methods=['POST'])
async def upload_files():
    if 'file' not in (await request.files) or 'file2' not in (await request.files):
        return jsonify({"error": "Missing one or more image files"}), 400
    
    file1 = (await request.files)['file']
    file2 = (await request.files)['file2']
    
    if file1.filename == '' or file2.filename == '':
        return jsonify({"error": "One or more files not selected"}), 400
    
    if file1 and file2:
        filename1 = 'image1.jpg'
        filename2 = 'image2.jpg'
        filepath1 = os.path.join(UPLOAD_FOLDER, filename1)
        filepath2 = os.path.join(UPLOAD_FOLDER, filename2)
        await file1.save(filepath1)
        await file2.save(filepath2)

        img_height, img_width = 256, 256

        try:
            image1 = Image.open(filepath1)
            image2 = Image.open(filepath2)
        except UnidentifiedImageError:
            return jsonify({"error": "Cannot identify image file"}), 400

        reduced_quality_image1 = pre_preprocess_image(image1, img_width, filename1)
        reduced_quality_image2 = pre_preprocess_image(image2, img_width, filename2)

        final_image1 = preprocess_image(reduced_quality_image1, 'final_image1.jpg')
        final_image2 = preprocess_image(reduced_quality_image2, 'final_image2.jpg')

        if final_image1 is None or final_image2 is None:
            return jsonify({"error": "Failed to preprocess one or both images"}), 500
        
        final_image_filename1 = f"final_{filename1}"
        final_image_filename2 = f"final_{filename2}"
        final_image_filepath1 = os.path.join(UPLOAD_FOLDER, final_image_filename1)
        final_image_filepath2 = os.path.join(UPLOAD_FOLDER, final_image_filename2)

        cv2.imwrite(final_image_filepath1, cv2.cvtColor(final_image1, cv2.COLOR_RGB2BGR))
        cv2.imwrite(final_image_filepath2, cv2.cvtColor(final_image2, cv2.COLOR_RGB2BGR))

        concatenated_image_s = np.hstack((final_image1, final_image2))
        concatenated_image_resized = cv2.resize(concatenated_image_s, (512, 256))

        concat_img_height = 256
        concat_img_width = 512

        concatenated_image_filename = "concatenated_image.jpg"
        concatenated_image_filepath = os.path.join(UPLOAD_FOLDER, concatenated_image_filename)
        cv2.imwrite(concatenated_image_filepath, cv2.cvtColor(concatenated_image_resized, cv2.COLOR_RGB2BGR))
    
        
        

        concat_image_np = np.array(concatenated_image_s)
        concat_image_np = concat_image_np.reshape((1, concat_img_height, concat_img_width, 3))

        np_file_path = os.path.join(UPLOAD_FOLDER, 'concatenated_image.npy')
        np.save(np_file_path, concat_image_np)

        print ("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        predictions = await send_to_model(concat_image_np)
        print ("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        print (predictions['predictions'][0])
        if max(predictions['predictions'][0]) < 0.5:
            top_3_indices = np.argpartition(predictions['predictions'][0], -3)[-3:][::-1]
            key1 = "KM# " + class_names[top_3_indices[0]]
            key2 = "KM# " + class_names[top_3_indices[1]]
            key3 = "KM# " + class_names[top_3_indices[2]]
            
            coin_info = {
            "Number": "",
            "Country": "",
            "Period": "Couldn't identify the coin.",
            "Coin type": "",
            "Denomination": "Top 3 matches are given.",
            "Currency rate": "",
            "Year": "",
            "Composition": "",
            "Edge type": "",
            "Edge description": "",
            "Shape": "",
            "Alignment": "",
            "Weight (g)": "",
            "Diameter (mm)": "",
            "Thickness (mm)": ""
            }
            
            coin_info["Number"] = key1 + ", " + key2 + ", " + key3
            

            
        else:
            key = concat_class_names[np.argmax(predictions['predictions'][0])]
            coin_info = requests.get(f"https://coinrecognition.onrender.com/get_info_concat/{key}").json()

        # predicted_class = concat_class_names[np.argmax(predictions[0])]


        print(coin_info)

        # Define filenames here
        cropped_rotated_filename = 'cropped_rotated_' + filename1
        final_image_filename = f"final_{filename1}"

        return jsonify({
            "message": "File uploaded successfully",
            "filename": cropped_rotated_filename,
            "reduced_quality_filename": f"reduced_quality_{filename1}",
            "final_image_filename": final_image_filename,
            #"predicted_class": predicted_class,
            "coin_info": coin_info
        }), 200

    return jsonify({"error": "Invalid request"}), 400







def gallery_preprocess_image(image):
    offset = 1
    param2Value = 110
    param2Change = 7

    # Convert PIL image to numpy array
    image_np = np.array(image)

    image1 = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)
    image1 = cv2.blur(image1, (7, 7))
    orgGray = np.array(image1, copy=True)

    height, width = image_np.shape[:2]
    circles = None
    while (circles is None) and (param2Value > 50):
        image1 = np.array(orgGray, copy=True)
        circles = cv2.HoughCircles(image1, cv2.HOUGH_GRADIENT, 1, 40,
                                   param1=60, param2=param2Value, minRadius=0, maxRadius=0)
        param2Value -= param2Change

    if circles is not None:
        original = np.array(circles, copy=True)
        circles = np.uint16(np.around(circles))
        mask = np.zeros_like(image1)

        maxCircle = max(circles[0, :], key=lambda x: x[2])
        radius = int(maxCircle[2] * offset)
        cv2.circle(mask, (maxCircle[0], maxCircle[1]), radius, (255, 255, 255), thickness=-1)

        top = int(maxCircle[1] - radius)
        bottom = int(maxCircle[1] + radius)
        left = int(maxCircle[0] - radius)
        right = int(maxCircle[0] + radius)

        result = cv2.bitwise_and(image_np, image_np, mask=mask)
        isolated = result[top:bottom, left:right]

        isolated = cv2.resize(isolated, (256, 256))

        return isolated
    else:
        return None
    

async def gallery_send_to_model(image_np):
    data = json.dumps({"signature_name": "serving_default", "instances": image_np.tolist()})
    headers = {"content-type": "application/json"}
    async with ClientSession() as session:
        async with session.post('https://coin-model-7ynk.onrender.com/v1/models/coin_model:predict', data=data, headers=headers) as response:
            return await response.json()





@app.route('/gallery-upload', methods=['POST'])
async def upload_file():
    if 'file' not in (await request.files):
        return jsonify({"error": "No file part"}), 400
    
    file = (await request.files)['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400
    
    if file:
        filename = 'image.jpg'
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        await file.save(filepath)

        try:
            image = Image.open(filepath)
        except UnidentifiedImageError:
            return jsonify({"error": "Cannot identify image file"}), 400

        print(f"Image received: {filename}")

        img_height, img_width = 256, 256

        rotated_image = image.rotate(-90, expand=True)
        rotated_filename = 'rotated_' + filename
        rotated_filepath = os.path.join(UPLOAD_FOLDER, rotated_filename)
        rotated_image.save(rotated_filepath)

        min_dimension = min(rotated_image.width, rotated_image.height)
        left = (rotated_image.width - min_dimension) / 2
        top = (rotated_image.height - min_dimension) / 2
        right = left + min_dimension
        bottom = top + min_dimension
        cropped_rotated_image = rotated_image.crop((left, top, right, bottom))

        cropped_rotated_filename = 'cropped_rotated_' + filename
        cropped_rotated_filepath = os.path.join(UPLOAD_FOLDER, cropped_rotated_filename)
        cropped_rotated_image.save(cropped_rotated_filepath)

        resized_image = cropped_rotated_image.resize((img_width, img_width))

        reduced_quality_filepath = os.path.join(UPLOAD_FOLDER, f"reduced_quality_{filename}")
        reduced_quality_image = resized_image.copy()
        reduced_quality_image.save(reduced_quality_filepath, quality=90)

        final_image = gallery_preprocess_image(reduced_quality_image)

        if final_image is None:
            return jsonify({"error": "Failed to preprocess image"}), 500

        final_image_filename = f"final_{filename}"
        final_image_filepath = os.path.join(UPLOAD_FOLDER, final_image_filename)

        # Save the final preprocessed image
        cv2.imwrite(final_image_filepath, cv2.cvtColor(final_image, cv2.COLOR_RGB2BGR))

        image_np = np.array(final_image)
        image_np = image_np.reshape((1, img_width, img_width, 3))

        np.save(os.path.join(UPLOAD_FOLDER, "image_np.npy"), image_np)

        predictions = await gallery_send_to_model(image_np)
        
        if max(predictions['predictions'][0]) < 0.5:
            top_3_indices = np.argpartition(predictions['predictions'][0], -3)[-3:][::-1]
            key1 = "KM# " + class_names[top_3_indices[0]]
            key2 = "KM# " + class_names[top_3_indices[1]]
            key3 = "KM# " + class_names[top_3_indices[2]]
            
            coin_info = {
            "Number": "",
            "Country": "",
            "Period": "Couldn't identify the coin.",
            "Coin type": "",
            "Denomination": "Top 3 matches are given.",
            "Currency rate": "",
            "Year": "",
            "Composition": "",
            "Edge type": "",
            "Edge description": "",
            "Shape": "",
            "Alignment": "",
            "Weight (g)": "",
            "Diameter (mm)": "",
            "Thickness (mm)": ""
            }
            
            coin_info["Number"] = key1 + ", " + key2 + ", " + key3
            

            
        else:
            key = class_names[np.argmax(predictions['predictions'][0])]
            coin_info = requests.get(f"https://coinrecognition.onrender.com/get_info/{key}").json()


        

        print(coin_info)
        

        return jsonify({
            "message": "File uploaded successfully",
            "filename": cropped_rotated_filename,
            "reduced_quality_filename": f"reduced_quality_{filename}",
            "final_image_filename": final_image_filename,
            "coin_info": coin_info
        }), 200


    return jsonify({"error": "Invalid request"}), 400


@app.route('/uploads/<filename>')
async def uploaded_file(filename):
    return await send_from_directory(UPLOAD_FOLDER, filename)

if __name__ == '__main__':
    app.run(debug=True, use_reloader=False, host='0.0.0.0')
