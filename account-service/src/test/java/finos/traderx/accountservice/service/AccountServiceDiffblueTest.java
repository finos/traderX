package finos.traderx.accountservice.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isA;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.repository.AccountRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.repository.CrudRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {AccountService.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class AccountServiceDiffblueTest {
  @MockBean
  private AccountRepository accountRepository;

  @Autowired
  private AccountService accountService;

  /**
   * Test {@link AccountService#getAllAccount()}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code 42}.</li>
   *   <li>Then return size is two.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); given Account (default constructor) DisplayName is '42'; then return size is two")
  void testGetAllAccount_givenAccountDisplayNameIs42_thenReturnSizeIsTwo() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);

    Account account2 = new Account();
    account2.setDisplayName("42");
    account2.setId(2);

    ArrayList<Account> accountList = new ArrayList<>();
    accountList.add(account2);
    accountList.add(account);
    when(accountRepository.findAll()).thenReturn(accountList);

    // Act
    List<Account> actualAllAccount = accountService.getAllAccount();

    // Assert
    verify(accountRepository).findAll();
    assertEquals(2, actualAllAccount.size());
    Account getResult = actualAllAccount.get(0);
    assertEquals("42", getResult.getDisplayName());
    assertEquals(2, getResult.getId());
    assertSame(account, actualAllAccount.get(1));
  }

  /**
   * Test {@link AccountService#getAllAccount()}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code Display Name}.</li>
   *   <li>Then return {@link ArrayList#ArrayList()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); given Account (default constructor) DisplayName is 'Display Name'; then return ArrayList()")
  void testGetAllAccount_givenAccountDisplayNameIsDisplayName_thenReturnArrayList() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);

    ArrayList<Account> accountList = new ArrayList<>();
    accountList.add(account);
    when(accountRepository.findAll()).thenReturn(accountList);

    // Act
    List<Account> actualAllAccount = accountService.getAllAccount();

    // Assert
    verify(accountRepository).findAll();
    assertEquals(accountList, actualAllAccount);
  }

  /**
   * Test {@link AccountService#getAllAccount()}.
   * <ul>
   *   <li>Given {@link AccountRepository} {@link CrudRepository#findAll()} return
   * {@link ArrayList#ArrayList()}.</li>
   *   <li>Then return Empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); given AccountRepository findAll() return ArrayList(); then return Empty")
  void testGetAllAccount_givenAccountRepositoryFindAllReturnArrayList_thenReturnEmpty() {
    // Arrange
    when(accountRepository.findAll()).thenReturn(new ArrayList<>());

    // Act
    List<Account> actualAllAccount = accountService.getAllAccount();

    // Assert
    verify(accountRepository).findAll();
    assertTrue(actualAllAccount.isEmpty());
  }

  /**
   * Test {@link AccountService#getAllAccount()}.
   * <ul>
   *   <li>Then throw {@link ResourceNotFoundException}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); then throw ResourceNotFoundException")
  void testGetAllAccount_thenThrowResourceNotFoundException() {
    // Arrange
    when(accountRepository.findAll()).thenThrow(new ResourceNotFoundException("An error occurred"));

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountService.getAllAccount());
    verify(accountRepository).findAll();
  }

  /**
   * Test {@link AccountService#getAccountById(int)}.
   * <p>
   * Method under test: {@link AccountService#getAccountById(int)}
   */
  @Test
  @DisplayName("Test getAccountById(int)")
  void testGetAccountById() throws ResourceNotFoundException {
    // Arrange
    when(accountRepository.findById(Mockito.<Integer>any()))
        .thenThrow(new ResourceNotFoundException("An error occurred"));

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountService.getAccountById(1));
    verify(accountRepository).findById(eq(1));
  }

  /**
   * Test {@link AccountService#getAccountById(int)}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code Display Name}.</li>
   *   <li>Then return {@link Account} (default constructor).</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAccountById(int)}
   */
  @Test
  @DisplayName("Test getAccountById(int); given Account (default constructor) DisplayName is 'Display Name'; then return Account (default constructor)")
  void testGetAccountById_givenAccountDisplayNameIsDisplayName_thenReturnAccount() throws ResourceNotFoundException {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    Optional<Account> ofResult = Optional.of(account);
    when(accountRepository.findById(Mockito.<Integer>any())).thenReturn(ofResult);

    // Act
    Account actualAccountById = accountService.getAccountById(1);

    // Assert
    verify(accountRepository).findById(eq(1));
    assertSame(account, actualAccountById);
  }

  /**
   * Test {@link AccountService#getAccountById(int)}.
   * <ul>
   *   <li>Given {@link AccountRepository} {@link CrudRepository#findById(Object)}
   * return empty.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#getAccountById(int)}
   */
  @Test
  @DisplayName("Test getAccountById(int); given AccountRepository findById(Object) return empty")
  void testGetAccountById_givenAccountRepositoryFindByIdReturnEmpty() throws ResourceNotFoundException {
    // Arrange
    Optional<Account> emptyResult = Optional.empty();
    when(accountRepository.findById(Mockito.<Integer>any())).thenReturn(emptyResult);

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountService.getAccountById(1));
    verify(accountRepository).findById(eq(1));
  }

  /**
   * Test {@link AccountService#upsertAccount(Account)}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code Display Name}.</li>
   *   <li>Then return {@link Account} (default constructor).</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#upsertAccount(Account)}
   */
  @Test
  @DisplayName("Test upsertAccount(Account); given Account (default constructor) DisplayName is 'Display Name'; then return Account (default constructor)")
  void testUpsertAccount_givenAccountDisplayNameIsDisplayName_thenReturnAccount() {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    when(accountRepository.save(Mockito.<Account>any())).thenReturn(account);

    Account account2 = new Account();
    account2.setDisplayName("Display Name");
    account2.setId(1);

    // Act
    Account actualUpsertAccountResult = accountService.upsertAccount(account2);

    // Assert
    verify(accountRepository).save(isA(Account.class));
    assertSame(account, actualUpsertAccountResult);
  }

  /**
   * Test {@link AccountService#upsertAccount(Account)}.
   * <ul>
   *   <li>Then throw {@link ResourceNotFoundException}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountService#upsertAccount(Account)}
   */
  @Test
  @DisplayName("Test upsertAccount(Account); then throw ResourceNotFoundException")
  void testUpsertAccount_thenThrowResourceNotFoundException() {
    // Arrange
    when(accountRepository.save(Mockito.<Account>any())).thenThrow(new ResourceNotFoundException("An error occurred"));

    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);

    // Act and Assert
    assertThrows(ResourceNotFoundException.class, () -> accountService.upsertAccount(account));
    verify(accountRepository).save(isA(Account.class));
  }
}
