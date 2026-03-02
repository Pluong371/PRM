package com.shopweb.service.customer;

import com.shopweb.dto.response.WarrantyResponse;
import com.shopweb.model.entity.OrderItem;
import com.shopweb.repository.OrderItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
public class WarrantyService {

    @Autowired
    private OrderItemRepository orderItemRepository;

    public WarrantyResponse checkWarrantyBySerial(String serialNumber) {

        // 🔥 Test raw query trước
        Object raw = orderItemRepository.getWarrantyRaw(serialNumber);
        System.out.println("==================================");
        System.out.println("RAW from DB: " + raw);

        OrderItem item = orderItemRepository.findBySerialNumber(serialNumber)
                .orElseThrow(() -> new RuntimeException("Serial not found"));

        System.out.println("Entity value: " + item.getWarrantyEndDate());
        System.out.println("==================================");

        boolean valid = false;

        if (item.getWarrantyEndDate() != null) {
            LocalDate warrantyDate = item.getWarrantyEndDate().toLocalDate();
            LocalDate today = LocalDate.now();
            valid = !warrantyDate.isBefore(today);
        }

        return new WarrantyResponse(
                item.getProduct().getName(),
                item.getSerialNumber(),
                item.getWarrantyEndDate(),
                valid ? "VALID" : "EXPIRED"
        );
    }
}