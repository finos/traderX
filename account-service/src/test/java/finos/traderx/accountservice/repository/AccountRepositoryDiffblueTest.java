package finos.traderx.accountservice.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import finos.traderx.accountservice.model.Account;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.repository.CrudRepository;
import org.springframework.test.context.ContextConfiguration;

@ContextConfiguration(classes = {AccountRepository.class})
@EnableAutoConfiguration
@EntityScan(basePackages = {"finos.traderx.accountservice.model"})
@DataJpaTest
class AccountRepositoryDiffblueTest {
  @Autowired
  private AccountRepository accountRepository;

  /**
   * Test {@link CrudRepository#count()}.
   * <p>
   * Method under test: {@link AccountRepository#count()}
   */
  @Test
  @DisplayName("Test count()")
  void testCount() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account);
    accountRepository.save(account2);

    // Act and Assert
    assertEquals(2L, accountRepository.count());
  }

  /**
   * Test {@link CrudRepository#delete(Object)}.
   * <p>
   * Method under test: {@link AccountRepository#delete(Object)}
   */
  @Test
  @DisplayName("Test delete(Object)")
  void testDelete() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");

    Account account3 = new Account();
    account3.setDisplayName("Display Name");
    accountRepository.save(account);
    accountRepository.save(account2);
    accountRepository.save(account3);

    // Act
    accountRepository.delete(account3);

    // Assert
    Iterable<Account> findAllResult = accountRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(2, ((List<Account>) findAllResult).size());
    Account getResult = ((List<Account>) findAllResult).get(1);
    assertEquals("42", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) findAllResult).get(0);
    assertEquals("Display Name", getResult2.getDisplayName());
    assertSame(account, getResult2);
    assertSame(account2, getResult);
  }

  /**
   * Test {@link CrudRepository#deleteAll()}.
   * <p>
   * Method under test: {@link AccountRepository#deleteAll()}
   */
  @Test
  @DisplayName("Test deleteAll()")
  void testDeleteAll() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account);
    accountRepository.save(account2);

    // Act
    accountRepository.deleteAll();

    // Assert
    Iterable<Account> findAllResult = accountRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertTrue(((List<Account>) findAllResult).isEmpty());
  }

  /**
   * Test {@link CrudRepository#deleteAllById(Iterable)}.
   * <p>
   * Method under test: {@link AccountRepository#deleteAllById(Iterable)}
   */
  @Test
  @DisplayName("Test deleteAllById(Iterable)")
  void testDeleteAllById() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");

    Account account3 = new Account();
    account3.setDisplayName("Display Name");

    Account account4 = new Account();
    account4.setDisplayName("Display Name");

    Account account5 = new Account();
    account5.setDisplayName("Display Name");
    accountRepository.save(account);
    accountRepository.save(account2);
    accountRepository.save(account3);
    accountRepository.save(account4);
    accountRepository.save(account5);
    int id = account3.getId();
    int id2 = account4.getId();
    List<Integer> ids = Arrays.asList(id, id2, account5.getId());

    // Act
    accountRepository.deleteAllById(ids);

    // Assert
    Iterable<Account> findAllResult = accountRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(2, ((List<Account>) findAllResult).size());
    Account getResult = ((List<Account>) findAllResult).get(1);
    assertEquals("42", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) findAllResult).get(0);
    assertEquals("Display Name", getResult2.getDisplayName());
    assertSame(account, getResult2);
    assertSame(account2, getResult);
  }

  /**
   * Test {@link CrudRepository#deleteAll(Iterable)} with {@code Iterable}.
   * <p>
   * Method under test: {@link AccountRepository#deleteAll(Iterable)}
   */
  @Test
  @DisplayName("Test deleteAll(Iterable) with 'Iterable'")
  void testDeleteAllWithIterable() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");

    Account account3 = new Account();
    account3.setDisplayName("Display Name");

    Account account4 = new Account();
    account4.setDisplayName("Display Name");

    Account account5 = new Account();
    account5.setDisplayName("Display Name");
    accountRepository.save(account);
    accountRepository.save(account2);
    accountRepository.save(account3);
    accountRepository.save(account4);
    accountRepository.save(account5);
    List<Account> entities = Arrays.asList(account3, account4, account5);

    // Act
    accountRepository.deleteAll(entities);

    // Assert
    Iterable<Account> findAllResult = accountRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(2, ((List<Account>) findAllResult).size());
    Account getResult = ((List<Account>) findAllResult).get(1);
    assertEquals("42", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) findAllResult).get(0);
    assertEquals("Display Name", getResult2.getDisplayName());
    assertSame(account, getResult2);
    assertSame(account2, getResult);
  }

  /**
   * Test {@link CrudRepository#deleteById(Object)}.
   * <p>
   * Method under test: {@link AccountRepository#deleteById(Object)}
   */
  @Test
  @DisplayName("Test deleteById(Object)")
  void testDeleteById() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    accountRepository.save(account);

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account2);

    Account account3 = new Account();
    account3.setDisplayName("Display Name");
    accountRepository.save(account3);

    // Act
    accountRepository.deleteById(account3.getId());

    // Assert
    Iterable<Account> findAllResult = accountRepository.findAll();
    assertTrue(findAllResult instanceof List);
    assertEquals(2, ((List<Account>) findAllResult).size());
    Account getResult = ((List<Account>) findAllResult).get(1);
    assertEquals("42", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) findAllResult).get(0);
    assertEquals("Display Name", getResult2.getDisplayName());
    assertSame(account, getResult2);
    assertSame(account2, getResult);
  }

  /**
   * Test {@link CrudRepository#existsById(Object)}.
   * <ul>
   *   <li>Given one.</li>
   *   <li>When {@link Account} (default constructor) Id is one.</li>
   *   <li>Then return {@code false}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountRepository#existsById(Object)}
   */
  @Test
  @DisplayName("Test existsById(Object); given one; when Account (default constructor) Id is one; then return 'false'")
  void testExistsById_givenOne_whenAccountIdIsOne_thenReturnFalse() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");

    Account account3 = new Account();
    account3.setId(1);
    account3.setDisplayName("Display Name");
    int id = account3.getId();
    accountRepository.save(account);
    accountRepository.save(account2);
    accountRepository.save(account3);

    // Act and Assert
    assertFalse(accountRepository.existsById(id));
  }

  /**
   * Test {@link CrudRepository#existsById(Object)}.
   * <ul>
   *   <li>When {@link AccountRepository} save {@link Account} (default
   * constructor).</li>
   *   <li>Then return {@code true}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountRepository#existsById(Object)}
   */
  @Test
  @DisplayName("Test existsById(Object); when AccountRepository save Account (default constructor); then return 'true'")
  void testExistsById_whenAccountRepositorySaveAccount_thenReturnTrue() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    accountRepository.save(account);

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account2);

    Account account3 = new Account();
    account3.setDisplayName("Display Name");
    accountRepository.save(account3);

    // Act and Assert
    assertTrue(accountRepository.existsById(account3.getId()));
  }

  /**
   * Test {@link CrudRepository#findAll()}.
   * <p>
   * Method under test: {@link AccountRepository#findAll()}
   */
  @Test
  @DisplayName("Test findAll()")
  void testFindAll() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account);
    accountRepository.save(account2);

    // Act
    Iterable<Account> actualFindAllResult = accountRepository.findAll();

    // Assert
    assertTrue(actualFindAllResult instanceof List);
    assertEquals(2, ((List<Account>) actualFindAllResult).size());
    Account getResult = ((List<Account>) actualFindAllResult).get(1);
    assertEquals("42", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) actualFindAllResult).get(0);
    assertEquals("Display Name", getResult2.getDisplayName());
    assertSame(account, getResult2);
    assertSame(account2, getResult);
  }

  /**
   * Test {@link CrudRepository#findAllById(Iterable)}.
   * <p>
   * Method under test: {@link AccountRepository#findAllById(Iterable)}
   */
  @Test
  @DisplayName("Test findAllById(Iterable)")
  void testFindAllById() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("42");

    Account account3 = new Account();
    account3.setDisplayName("Display Name");

    Account account4 = new Account();
    account4.setDisplayName("Display Name");

    Account account5 = new Account();
    account5.setDisplayName("Display Name");
    accountRepository.save(account);
    accountRepository.save(account2);
    accountRepository.save(account3);
    accountRepository.save(account4);
    accountRepository.save(account5);
    int id = account3.getId();
    int id2 = account4.getId();
    List<Integer> ids = Arrays.asList(id, id2, account5.getId());

    // Act
    Iterable<Account> actualFindAllByIdResult = accountRepository.findAllById(ids);

    // Assert
    assertTrue(actualFindAllByIdResult instanceof List);
    assertEquals(3, ((List<Account>) actualFindAllByIdResult).size());
    Account getResult = ((List<Account>) actualFindAllByIdResult).get(0);
    assertEquals("Display Name", getResult.getDisplayName());
    Account getResult2 = ((List<Account>) actualFindAllByIdResult).get(1);
    assertEquals("Display Name", getResult2.getDisplayName());
    Account getResult3 = ((List<Account>) actualFindAllByIdResult).get(2);
    assertEquals("Display Name", getResult3.getDisplayName());
    assertSame(account3, getResult);
    assertSame(account4, getResult2);
    assertSame(account5, getResult3);
  }

  /**
   * Test {@link CrudRepository#findById(Object)}.
   * <p>
   * Method under test: {@link AccountRepository#findById(Object)}
   */
  @Test
  @DisplayName("Test findById(Object)")
  void testFindById() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    accountRepository.save(account);

    Account account2 = new Account();
    account2.setDisplayName("42");
    accountRepository.save(account2);

    Account account3 = new Account();
    account3.setDisplayName("Display Name");
    accountRepository.save(account3);

    // Act
    Optional<Account> actualFindByIdResult = accountRepository.findById(account3.getId());

    // Assert
    Account getResult = actualFindByIdResult.get();
    assertEquals("Display Name", getResult.getDisplayName());
    assertTrue(actualFindByIdResult.isPresent());
    assertSame(account3, getResult);
  }

  /**
   * Test {@link CrudRepository#save(Object)}.
   * <p>
   * Method under test: {@link AccountRepository#save(Object)}
   */
  @Test
  @DisplayName("Test save(Object)")
  void testSave() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    // Act
    Account actualSaveResult = accountRepository.save(account);

    // Assert
    assertEquals("Display Name", actualSaveResult.getDisplayName());
    assertSame(account, actualSaveResult);
  }

  /**
   * Test {@link CrudRepository#saveAll(Iterable)}.
   * <p>
   * Method under test: {@link AccountRepository#saveAll(Iterable)}
   */
  @Test
  @DisplayName("Test saveAll(Iterable)")
  void testSaveAll() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");

    Account account2 = new Account();
    account2.setDisplayName("Display Name");

    Account account3 = new Account();
    account3.setDisplayName("Display Name");
    List<Account> entities = Arrays.asList(account, account2, account3);

    // Act and Assert
    assertEquals(entities, accountRepository.saveAll(entities));
  }
}
