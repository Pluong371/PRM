package com.shopweb.repository;

import com.shopweb.model.entity.Cart;
import com.shopweb.model.entity.CartItem;
import com.shopweb.model.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    // Dùng khi add to cart (đã có sp trong cart chưa)
    Optional<CartItem> findByCartAndProduct(Cart cart, Product product);

    // Dùng khi load cart
    List<CartItem> findAllByCart(Cart cart);
}
