package finos.traderx.positionservice.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.repository.PositionRepository;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {PositionService.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class PositionServiceDiffblueTest {
  @MockBean
  private PositionRepository positionRepository;

  @Autowired
  private PositionService positionService;

  /**
   * Test {@link PositionService#getAllPositions()}.
   * <ul>
   *   <li>Given {@link Position} (default constructor) AccountId is one.</li>
   *   <li>Then return size is one.</li>
   * </ul>
   * <p>
   * Method under test: {@link PositionService#getAllPositions()}
   */
  @Test
  @DisplayName("Test getAllPositions(); given Position (default constructor) AccountId is one; then return size is one")
  void testGetAllPositions_givenPositionAccountIdIsOne_thenReturnSizeIsOne() {
    // Arrange
    Position position = new Position();
    position.setAccountId(1);
    position.setQuantity(1);
    position.setSecurity("Security");
    position.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    ArrayList<Position> positionList = new ArrayList<>();
    positionList.add(position);
    when(positionRepository.findAll()).thenReturn(positionList);

    // Act
    List<Position> actualAllPositions = positionService.getAllPositions();

    // Assert
    verify(positionRepository).findAll();
    assertEquals(1, actualAllPositions.size());
    Position getResult = actualAllPositions.get(0);
    assertEquals("Security", getResult.getSecurity());
    assertEquals(1, getResult.getAccountId().intValue());
    assertEquals(1, getResult.getQuantity().intValue());
  }

  /**
   * Test {@link PositionService#getAllPositions()}.
   * <ul>
   *   <li>Given {@link Position} (default constructor) AccountId is two.</li>
   *   <li>Then return size is two.</li>
   * </ul>
   * <p>
   * Method under test: {@link PositionService#getAllPositions()}
   */
  @Test
  @DisplayName("Test getAllPositions(); given Position (default constructor) AccountId is two; then return size is two")
  void testGetAllPositions_givenPositionAccountIdIsTwo_thenReturnSizeIsTwo() {
    // Arrange
    Position position = new Position();
    position.setAccountId(1);
    position.setQuantity(1);
    position.setSecurity("Security");
    position.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position position2 = new Position();
    position2.setAccountId(2);
    position2.setQuantity(0);
    position2.setSecurity("42");
    position2.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    ArrayList<Position> positionList = new ArrayList<>();
    positionList.add(position2);
    positionList.add(position);
    when(positionRepository.findAll()).thenReturn(positionList);

    // Act
    List<Position> actualAllPositions = positionService.getAllPositions();

    // Assert
    verify(positionRepository).findAll();
    assertEquals(2, actualAllPositions.size());
    Position getResult = actualAllPositions.get(0);
    assertEquals("42", getResult.getSecurity());
    assertEquals(0, getResult.getQuantity().intValue());
    assertEquals(2, getResult.getAccountId().intValue());
    assertSame(position, actualAllPositions.get(1));
  }

  /**
   * Test {@link PositionService#getAllPositions()}.
   * <ul>
   *   <li>Then return Empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link PositionService#getAllPositions()}
   */
  @Test
  @DisplayName("Test getAllPositions(); then return Empty")
  void testGetAllPositions_thenReturnEmpty() {
    // Arrange
    when(positionRepository.findAll()).thenReturn(new ArrayList<>());

    // Act
    List<Position> actualAllPositions = positionService.getAllPositions();

    // Assert
    verify(positionRepository).findAll();
    assertTrue(actualAllPositions.isEmpty());
  }

  /**
   * Test {@link PositionService#getPositionsByAccountID(int)}.
   * <p>
   * Method under test: {@link PositionService#getPositionsByAccountID(int)}
   */
  @Test
  @DisplayName("Test getPositionsByAccountID(int)")
  void testGetPositionsByAccountID() {
    // Arrange
    when(positionRepository.findByAccountId(Mockito.<Integer>any())).thenReturn(new ArrayList<>());

    // Act
    List<Position> actualPositionsByAccountID = positionService.getPositionsByAccountID(1);

    // Assert
    verify(positionRepository).findByAccountId(eq(1));
    assertTrue(actualPositionsByAccountID.isEmpty());
  }
}
