package finos.traderx.ordermatcher.repository;

import finos.traderx.ordermatcher.model.OrderRecord;
import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;

public interface OrderRepository extends JpaRepository<OrderRecord, String> {
    List<OrderRecord> findAllByOrderByUpdatedAtDesc();

    long countByStatusIn(Collection<OrderStatus> statuses);

    long countByStatusInAndRemainingQuantityGreaterThan(Collection<OrderStatus> statuses, Integer remainingQuantity);

    long countByStatusInAndSide(Collection<OrderStatus> statuses, OrderSide side);

    long countByStatus(OrderStatus status);

    @Query("select o.orderId from OrderRecord o")
    List<String> findAllOrderIds();
}

