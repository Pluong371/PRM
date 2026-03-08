const nodemailer = require("nodemailer");

class EmailService {
  constructor() {
    // Create SMTP transporter using Brevo (formerly Sendinblue)
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || "smtp-relay.brevo.com",
      port: parseInt(process.env.SMTP_PORT || "587"),
      secure: false, // true for 465, false for other ports like 587
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    this.senderEmail = process.env.MAIL_SENDER || "noreply@banhang.com";
    this.senderName = "BanHang Store";
  }

  /**
   * Send email using SMTP (Brevo)
   * @param {Object} options
   * @param {string} options.to - Recipient email address
   * @param {string} options.subject - Email subject
   * @param {string} options.html - Email HTML content
   * @param {string} options.text - Email text content (optional)
   * @returns {Promise<Object>} - Response from SMTP server
   */
  async sendEmail({ to, subject, html, text }) {
    try {
      if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
        console.warn("⚠️  SMTP credentials not configured. Email not sent.");
        return {
          success: false,
          message: "Email service not configured",
        };
      }

      const info = await this.transporter.sendMail({
        from: `"${this.senderName}" <${this.senderEmail}>`,
        to: to,
        subject: subject,
        html: html,
        text: text || this.stripHtml(html),
      });

      console.log("✅ Email sent successfully:", info.messageId);
      return {
        success: true,
        messageId: info.messageId,
        message: "Email sent successfully",
      };
    } catch (error) {
      console.error("❌ SMTP Email Service Error:", error.message);
      return {
        success: false,
        message: error.message || "Failed to send email",
        error: error.message,
      };
    }
  }

  /**
   * Strip HTML tags for plain text fallback
   * @param {string} html - HTML content
   * @returns {string} - Plain text
   */
  stripHtml(html) {
    return html
      .replace(/<[^>]*>/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  /**
   * Send OTP email
   * @param {string} to - Recipient email
   * @param {string} otp - OTP code
   * @param {string} fullName - User's full name
   * @returns {Promise<Object>} - Response
   */
  async sendOtpEmail(to, otp, fullName) {
    const subject = "Mã OTP xác nhận - BanHang Store";
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Xác nhận tài khoản BanHang</h2>
        <p>Xin chào ${fullName},</p>
        <p>Mã OTP xác nhận của bạn là:</p>
        <div style="background-color: #f0f0f0; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
          <h1 style="color: #007bff; letter-spacing: 5px; margin: 0;">${otp}</h1>
        </div>
        <p style="color: #666; font-size: 14px;">Mã OTP này sẽ hết hạn sau <strong>5 phút</strong>.</p>
        <p style="color: #666; font-size: 14px;">Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email này.</p>
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        <p style="color: #999; font-size: 12px;">© 2024 BanHang Store. All rights reserved.</p>
      </div>
    `;

    const text = `Mã OTP xác nhận của bạn là: ${otp}. Mã này sẽ hết hạn sau 5 phút.`;

    return await this.sendEmail({
      to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send password reset email
   * @param {string} to - Recipient email
   * @param {string} resetLink - Password reset link
   * @param {string} fullName - User's full name
   * @returns {Promise<Object>} - Response
   */
  async sendPasswordResetEmail(to, resetLink, fullName) {
    const subject = "Đặt lại mật khẩu - BanHang Store";
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Đặt lại mật khẩu</h2>
        <p>Xin chào ${fullName},</p>
        <p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn.</p>
        <p style="margin: 20px 0;">
          <a href="${resetLink}" style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Đặt lại mật khẩu
          </a>
        </p>
        <p style="color: #666; font-size: 14px;">Link này sẽ hết hạn sau <strong>1 giờ</strong>.</p>
        <p style="color: #666; font-size: 14px;">Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        <p style="color: #999; font-size: 12px;">© 2024 BanHang Store. All rights reserved.</p>
      </div>
    `;

    const text = `Nhấp vào liên kết sau để đặt lại mật khẩu: ${resetLink}. Link này sẽ hết hạn sau 1 giờ.`;

    return await this.sendEmail({
      to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send welcome email
   * @param {string} to - Recipient email
   * @param {string} fullName - User's full name
   * @returns {Promise<Object>} - Response
   */
  async sendWelcomeEmail(to, fullName) {
    const subject = "Chào mừng đến BanHang Store 🎉";
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Chào mừng đến BanHang Store! 🎉</h2>
        <p>Xin chào ${fullName},</p>
        <p>Cảm ơn bạn đã đăng ký tài khoản tại BanHang Store. Tài khoản của bạn đã sẵn sàng để sử dụng.</p>
        <p style="margin: 20px 0;">
          <a href="https://banhang.com/home" style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Bắt đầu mua sắm
          </a>
        </p>
        <p style="color: #666; font-size: 14px;">Với BanHang Store, bạn có thể:</p>
        <ul style="color: #666; font-size: 14px;">
          <li>Duyệt hàng ngàn sản phẩm thời trang</li>
          <li>Nhận ưu đãi độc quyền dành riêng cho thành viên</li>
          <li>Theo dõi đơn hàng của bạn theo thời gian thực</li>
          <li>Lưu các mục yêu thích của bạn để mua sau</li>
        </ul>
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        <p style="color: #999; font-size: 12px;">© 2024 BanHang Store. All rights reserved.</p>
      </div>
    `;

    const text = `Chào mừng đến BanHang Store! Tài khoản của bạn đã được tạo thành công.`;

    return await this.sendEmail({
      to,
      subject,
      html,
      text,
    });
  }
}

module.exports = EmailService;
