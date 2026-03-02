package com.shopweb.repository;

import com.shopweb.model.entity.OtpVerification;
import com.shopweb.model.enums.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface OtpVerificationRepository extends JpaRepository<OtpVerification, Long> {

  Optional<OtpVerification> findByEmailAndPurpose(String email, OtpPurpose purpose);

  void deleteByEmailAndPurpose(String email, OtpPurpose purpose);
}
