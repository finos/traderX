package finos.traderx.accountservice.model;

import java.io.Serializable;

public class AccountUserID implements Serializable {
	private Integer accountId;
	private String username;

	public AccountUserID() {
		// Entity
	}

	public AccountUserID(Integer accountId, String username) {
			this.accountId = accountId;
			this.username = username;
	}
}
