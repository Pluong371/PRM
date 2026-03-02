package com.shopweb.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;

@Component
public class AesUtil {

  private SecretKeySpec secretKey;

  @Value("${app.encryption.key}")
  public void setKey(String myKey) {
    MessageDigest sha = null;
    try {
      byte[] key = myKey.getBytes(StandardCharsets.UTF_8);
      sha = MessageDigest.getInstance("SHA-1");
      key = sha.digest(key);
      key = Arrays.copyOf(key, 16); // Use first 16 bytes for AES-128 (default crypto-js behavior with string key)
      secretKey = new SecretKeySpec(key, "AES");
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  public String decrypt(String strToDecrypt) {
    if (strToDecrypt == null)
      return null;

    try {
      Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5PADDING");
      cipher.init(Cipher.DECRYPT_MODE, secretKey);
      return new String(cipher.doFinal(Base64.getDecoder().decode(strToDecrypt)));
    } catch (Exception e) {
      // If it's not encrypted (e.g. legacy data or bypass), we might return the
      // original
      // or throw an error depending on strictness. Let's return original if
      // decryption fails.
      System.err.println("Error while decrypting: " + e.getMessage());
      return strToDecrypt;
    }
  }
}
