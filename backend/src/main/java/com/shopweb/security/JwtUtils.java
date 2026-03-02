package com.shopweb.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.security.Key;
import org.springframework.security.core.GrantedAuthority;
import java.util.Collection;
import java.util.stream.Collectors;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Component
public class JwtUtils {

  // Should be in application.properties in production, hardcoded for simplicity
  // as requested
  private static final String JWT_SECRET = "superSecretKeyForShopWebProject1234567890!@#$%";
  private static final int JWT_EXPIRATION_MS = 86400000; // 24 hours

  private Key key() {
    return Keys.hmacShaKeyFor(JWT_SECRET.getBytes());
  }

  public String generateToken(String username, Collection<? extends GrantedAuthority> roles) {
    Map<String, Object> claims = new HashMap<>();
    claims.put("roles", roles.stream().map(GrantedAuthority::getAuthority).collect(Collectors.toList()));

    return Jwts.builder()
        .claims(claims)
        .subject(username)
        .issuedAt(new Date())
        .expiration(new Date((new Date()).getTime() + JWT_EXPIRATION_MS))
        .signWith(key())
        .compact();
  }

  public String getUserNameFromJwtToken(String token) {
    return Jwts.parser()
        .verifyWith((SecretKey) key())
        .build()
        .parseSignedClaims(token)
        .getPayload()
        .getSubject();
  }

  public boolean validateJwtToken(String authToken) {
    try {
      Jwts.parser()
          .verifyWith((SecretKey) key())
          .build()
          .parseSignedClaims(authToken);
      return true;
    } catch (MalformedJwtException e) {
      System.err.println("Invalid JWT token: " + e.getMessage());
    } catch (ExpiredJwtException e) {
      System.err.println("JWT token is expired: " + e.getMessage());
    } catch (UnsupportedJwtException e) {
      System.err.println("JWT token is unsupported: " + e.getMessage());
    } catch (IllegalArgumentException e) {
      System.err.println("JWT claims string is empty: " + e.getMessage());
    }
    return false;
  }
}
