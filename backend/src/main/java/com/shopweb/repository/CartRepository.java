package com.shopweb.repository;

import com.shopweb.model.entity.Cart;
import com.shopweb.model.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CartRepository extends JpaRepository<Cart, Long> {

    // Dùng khi đã có User object
    Optional<Cart> findByUser(User user);

    // ⭐ Tối ưu: dùng trực tiếp username (khuyên dùng cho API)
    Optional<Cart> findByUser_Username(String username);
}
