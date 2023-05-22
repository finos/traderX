export interface ActionButtonsProps {
	accountId: number;
}

export interface PeopleData {
	logonId: "string";
  fullName: "string";
  email: "string";
  employeeId: "string";
  department: "string";
  photoUrl: "string";
}

export type Side = 'Buy' | 'Sell' | undefined;

export interface RefData {
	ticker: string;
	companyName: string;
}

export interface RefDataCompanyNames {
	companyNames: string;
}

export interface TradeFormData {
	security: string;
	quantity: number;
}