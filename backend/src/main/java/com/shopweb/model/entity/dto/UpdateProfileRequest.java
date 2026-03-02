package com.shopweb.model.entity.dto;

import lombok.Data;

@Data
public class UpdateProfileRequest {
    private String fullName;
    private String email;
    private String phoneNumber;
    private String password; // dùng để xác nhận khi đổi email/sdt
}