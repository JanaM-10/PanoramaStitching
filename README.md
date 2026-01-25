# Panorama Stitching using MATLAB

## Overview

This project implements **Panorama Stitching** using **SIFT features** and **RANSAC-based homography estimation** in MATLAB.  
It allows users to load multiple images, optionally reorder them by similarity, and generate a stitched panorama using a simple **MATLAB App UI**.

The stitching pipeline supports:
- Feature extraction with **SIFT** (`vl_sift`)  
- Feature matching (`vl_ubcmatch`)  
- Homography estimation using **RANSAC**  
- Image warping and blending for seamless panoramas  

---


---

## Requirements

- **MATLAB R2022a or later** (App Designer compatible)  
- **VLFeat library** for SIFT features: [VLFeat download](http://www.vlfeat.org/)  
  (Make sure to run `vl_setup` before using the app)  

Optional: MATLAB Image Processing Toolbox for image reading, resizing, and display.

---

## Installation & Setup

## 1. Clone the repository:

bash
git clone https://github.com/YOUR_USERNAME/panorama-stitching-matlab.git
cd panorama-stitching-matlab

## 2.Open MATLAB and add the VLFeat toolbox to your path:
run('path_to_vlfeat/toolbox/vl_setup.m')

## Open the app in MATLAB:
open('PanoramaStitching_exported.m')

---

## Usage

- Load Images
Click Load Images in the App and select multiple images for stitching.

- Optional: Similarity Ordering
Check Use Similarity Ordering to automatically reorder images based on feature similarity.

- Stitch Images
Click Stitch to generate the panorama. The result will appear in the right-hand axes.

- Add / Remove Images

- Add Image: Add more images to the current set.
- Remove: Remove a selected thumbnail from the loaded images.

- Thumbnail Panel
Click on any thumbnail to select it. A red border will indicate the current selection.

---

## Notes

- Ensure the VLFeat toolbox is installed and set up in MATLAB.

- Large images are automatically resized to a maximum dimension of 400 pixels for faster processing.

- If images do not have enough matching points, stitching may fail.

- Works best with overlapping images and consistent lighting conditions.







