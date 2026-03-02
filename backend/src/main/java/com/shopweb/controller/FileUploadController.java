package com.shopweb.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.UUID;

/**
 * Handles file uploads (e.g., payment proof screenshots)
 */
@RestController
@RequestMapping("/api/upload")
public class FileUploadController {

  @Value("${upload.payment-proof.dir:uploads/payment-proofs}")
  private String uploadDir;

  /**
   * POST /api/upload/payment-proof
   * Upload a transfer screenshot and return its accessible URL.
   */
  @PostMapping("/payment-proof")
  public ResponseEntity<?> uploadPaymentProof(@RequestParam("file") MultipartFile file) {
    if (file.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("error", "File is empty"));
    }

    // Validate file type
    String contentType = file.getContentType();
    if (contentType == null || (!contentType.startsWith("image/"))) {
      return ResponseEntity.badRequest().body(Map.of("error", "Only image files are allowed"));
    }

    try {
      // Ensure directory exists
      Path dirPath = Paths.get(uploadDir);
      Files.createDirectories(dirPath);

      // Generate unique filename
      String originalFilename = file.getOriginalFilename();
      String extension = (originalFilename != null && originalFilename.contains("."))
          ? originalFilename.substring(originalFilename.lastIndexOf("."))
          : ".jpg";
      String fileName = "proof_" + UUID.randomUUID() + extension;

      // Save file
      Path filePath = dirPath.resolve(fileName);
      Files.copy(file.getInputStream(), filePath);

      // Return the URL path (served as static resource)
      String fileUrl = "/uploads/payment-proofs/" + fileName;
      return ResponseEntity.ok(Map.of("url", fileUrl));

    } catch (IOException e) {
      return ResponseEntity.internalServerError()
          .body(Map.of("error", "Failed to save file: " + e.getMessage()));
    }
  }
}
