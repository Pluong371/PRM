package com.shopweb.service.customer;

import com.shopweb.model.entity.Cart;
import com.shopweb.model.entity.CartItem;
import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.User;
import com.shopweb.repository.CartItemRepository;
import com.shopweb.repository.CartRepository;
import com.shopweb.repository.ProductRepository;
import com.shopweb.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Service for shopping cart operations
 */
@Service
@RequiredArgsConstructor
public class CustomerCartService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final ProductRepository productRepository;
    private final UserRepository userRepository;

    public List<CartItem> getCartItems(String username) {
        Cart cart = getOrCreateCart(username);
        // Refresh items from repository to ensure latest state
        return cartItemRepository.findAllByCart(cart);
    }

    @Transactional
    public List<CartItem> addToCart(String username, Long productId, int quantity) {
        Cart cart = getOrCreateCart(username);
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Product not found"));

        if (product.getStockQuantity() == null || product.getStockQuantity() <= 0) {
            throw new RuntimeException("Product is out of stock");
        }

        Optional<CartItem> existingItem = cartItemRepository.findByCartAndProduct(cart, product);

        int newQuantity = quantity;
        if (existingItem.isPresent()) {
            CartItem item = existingItem.get();
            newQuantity = item.getQuantity() + quantity;
        }

        if (newQuantity > product.getStockQuantity()) {
            throw new RuntimeException("Only " + product.getStockQuantity() + " items left in stock");
        }

        if (existingItem.isPresent()) {
            CartItem item = existingItem.get();
            item.setQuantity(newQuantity);
            cartItemRepository.save(item);
        } else {
            CartItem newItem = new CartItem(cart, product, quantity, product.getPrice());
            cartItemRepository.save(newItem);
        }

        return cartItemRepository.findAllByCart(cart);
    }

    @Transactional
    public List<CartItem> updateCartItem(String username, Long cartItemId, int quantity) {
        Cart cart = getOrCreateCart(username);
        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new RuntimeException("Cart item not found"));

        if (!item.getCart().getId().equals(cart.getId())) {
            throw new RuntimeException("Unauthorized access to cart item");
        }

        if (quantity <= 0) {
            cartItemRepository.delete(item);
        } else {
            item.setQuantity(quantity);
            if (item.getProduct().getStockQuantity() != null && quantity > item.getProduct().getStockQuantity()) {
                throw new RuntimeException("Only " + item.getProduct().getStockQuantity() + " items left in stock");
            }
            cartItemRepository.save(item);
        }
        return cartItemRepository.findAllByCart(cart);
    }

    @Transactional
    public List<CartItem> removeFromCart(String username, Long cartItemId) {
        Cart cart = getOrCreateCart(username);
        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new RuntimeException("Cart item not found"));

        if (!item.getCart().getId().equals(cart.getId())) {
            throw new RuntimeException("Unauthorized access to cart item");
        }

        cartItemRepository.delete(item);
        return cartItemRepository.findAllByCart(cart);
    }

    @Transactional
    public void clearCart(String username) {
        Cart cart = getOrCreateCart(username);
        List<CartItem> items = cartItemRepository.findAllByCart(cart);
        cartItemRepository.deleteAll(items);
    }

    private Cart getOrCreateCart(String username) {
        return cartRepository.findByUser_Username(username)
                .orElseGet(() -> {
                    User user = userRepository.findByUsername(username)
                            .orElseThrow(() -> new RuntimeException("User not found"));
                    Cart newCart = new Cart();
                    newCart.setUser(user);
                    return cartRepository.save(newCart);
                });
    }
}
