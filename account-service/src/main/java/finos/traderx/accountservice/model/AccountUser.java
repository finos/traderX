package finos.traderx.accountservice.model;

import java.io.Serializable;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

@Entity
@Table(name = "Accountusers")
@IdClass(AccountUserID.class)
public class AccountUser implements Serializable {

	@Id
	@Column(name = "AccountID")
	Integer accountId;

	@Id
	@Column(name = "Username")
	String username;

	public String getUsername() {
		return this.username;
	}

	public void setUsername(String username) {
		this.username = username;
	}

	public Integer getAccountId() {
		return this.accountId;
	}

	public void setAccountId(Integer accountId) {
		this.accountId = accountId;
	}

}
