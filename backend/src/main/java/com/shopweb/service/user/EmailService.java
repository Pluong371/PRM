package com.shopweb.service.user;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;

@Service
@Slf4j
public class EmailService {

  @Autowired
  private JavaMailSender emailSender;

  @Value("${app.mail.sender:noreply@shopweb.com}")
  private String senderEmail;

  public void sendOtpEmail(String toAddress, String otpCode, String purpose) {
    try {
      MimeMessage message = emailSender.createMimeMessage();
      MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

      helper.setTo(toAddress);

      String subject = purpose.equals("REGISTER")
          ? "Welcome to ShopWeb - Registration OTP"
          : "ShopWeb - Password Reset OTP";
      helper.setSubject(subject);

      String actionText = purpose.equals("REGISTER")
          ? "registering a new account"
          : "resetting your password";

      String htmlMsg = "<div style='font-family: Arial, sans-serif; padding: 20px; color: #333;'>"
          + "<h2 style='color: #d97706;'>ShopWeb Authentication</h2>"
          + "<p>Hello,</p>"
          + "<p>You are receiving this email because a request was made for " + actionText + ".</p>"
          + "<p>Your One-Time Password (OTP) is:</p>"
          + "<h1 style='background: #f3f4f6; padding: 10px; text-align: center; letter-spacing: 5px; color: #1f2937; border-radius: 5px;'>"
          + otpCode + "</h1>"
          + "<p>This code will expire in <b>5 minutes</b>.</p>"
          + "<p>If you did not request this, please ignore this email.</p>"
          + "<br>"
          + "<p>Best regards,<br>ShopWeb Security Team</p>"
          + "</div>";

      helper.setText(htmlMsg, true);

      // Note: Brevo/Sendinblue requires a verified sender address.
      helper.setFrom(senderEmail, "ShopWeb");

      emailSender.send(message);
      log.info("OTP email sent successfully to {}", toAddress);

    } catch (MessagingException | java.io.UnsupportedEncodingException e) {
      log.error("Failed to send OTP email to {}: {}", toAddress, e.getMessage());
      throw new RuntimeException("Failed to send email. Please try again later.");
    }
  }
}
