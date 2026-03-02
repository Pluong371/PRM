package com.shopweb.repository;

import com.shopweb.model.entity.WarrantyTicket;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WarrantyTicketRepository extends JpaRepository<WarrantyTicket, Long> {
    // Hàm này để sau này lấy danh sách lịch sử bảo hành của 1 máy
    List<WarrantyTicket> findBySerialNumberOrderByCreatedAtDesc(String serialNumber);
}