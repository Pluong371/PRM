package com.shopweb.repository;

import com.shopweb.model.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    Optional<OrderItem> findBySerialNumber(String serialNumber);

    // 🔥 Query trực tiếp DB để test
    @Query(value = "SELECT warranty_end_date FROM order_items WHERE serial_number = :serial", nativeQuery = true)
    Object getWarrantyRaw(@Param("serial") String serial);
}