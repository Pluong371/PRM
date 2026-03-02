package com.shopweb.service.user;

import com.shopweb.model.entity.OtpVerification;
import com.shopweb.model.enums.OtpPurpose;
import com.shopweb.repository.OtpVerificationRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
@Slf4j
public class OtpService {

  @Autowired
  private OtpVerificationRepository otpRepository;

  @Autowired
  private EmailService emailService;

  private static final int OTP_LENGTH = 6;
  private static final int COOLDOWN_SECONDS = 60;
  private static final int MAX_ATTEMPTS = 3;

  @Transactional
  public void generateAndSendOtp(String email, OtpPurpose purpose) {
    Optional<OtpVerification> existingOtpOpt = otpRepository.findByEmailAndPurpose(email, purpose);

    int newRequestCount = 1;

    if (existingOtpOpt.isPresent()) {
      OtpVerification existingOtp = existingOtpOpt.get();

      // Check Rate Limiting (Block the 5th request within the 5-minute expiry window)
      if (existingOtp.getRequestCount() >= 40000) {
        log.warn("Rate limit triggered for {} - purpose: {}", email, purpose);
        throw new RuntimeException("RATE_LIMIT_EXCEEDED"); // Throws on the 5th request
      }

      newRequestCount = existingOtp.getRequestCount() + 1;

      // Remove old OTP before generating new one
      otpRepository.delete(existingOtp);
    }

    // Generate 6-digit number
    String otpCode = generateSecureOtp();

    OtpVerification newOtp = new OtpVerification();
    newOtp.setEmail(email);
    newOtp.setOtpCode(otpCode);
    newOtp.setPurpose(purpose);
    newOtp.setRequestCount(newRequestCount);
    // createdAt and expiresAt are handled by @PrePersist

    otpRepository.save(newOtp);

    // Send Email
    emailService.sendOtpEmail(email, otpCode, purpose.name());
    log.info("Generated new OTP for {} - purpose: {}", email, purpose);
  }

  @Transactional
  public boolean verifyOtp(String email, String otpCode, OtpPurpose purpose) {
    Optional<OtpVerification> otpOpt = otpRepository.findByEmailAndPurpose(email, purpose);

    if (otpOpt.isEmpty()) {
      throw new RuntimeException("OTP_NOT_FOUND");
    }

    OtpVerification otpEntity = otpOpt.get();

    // 1. Check Expiry
    if (LocalDateTime.now().isAfter(otpEntity.getExpiresAt())) {
      otpRepository.delete(otpEntity);
      throw new RuntimeException("OTP_EXPIRED");
    }

    // 2. Check Match
    if (!otpEntity.getOtpCode().equals(otpCode)) {
      // Increment attempts
      otpEntity.setAttempts(otpEntity.getAttempts() + 1);

      // 3. Check Brute-Force limit
      if (otpEntity.getAttempts() >= MAX_ATTEMPTS) {
        otpRepository.delete(otpEntity);
        throw new RuntimeException("MAX_ATTEMPTS_REACHED");
      }

      otpRepository.save(otpEntity);
      throw new RuntimeException("INVALID_OTP");
    }

    // 4. Success -> Delete to prevent Replay Attacks
    log.info("OTP verified successfully for {} - purpose: {}", email, purpose);
    otpRepository.delete(otpEntity);
    return true;
  }

  private String generateSecureOtp() {
    SecureRandom random = new SecureRandom();
    int num = random.nextInt(900000) + 100000; // ensures 6 digits
    return String.valueOf(num);
  }
}
