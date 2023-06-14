import { SetStateAction, useEffect, useState } from "react";
import { TradeData } from "../Datatable/types";
import { Environment } from '../env';

export const GetTrades = (accountId:number) => {
	const [tradesData, setTradesData] = useState<TradeData[]>([]);
	type data = () => Promise<unknown>;

	useEffect(() => {
		let json:SetStateAction<TradeData[]>;
		const fetchData: data = async () => {
			try {
				const response = await fetch(`${Environment.position_service_url}/trades/${accountId}`);
				if (response.ok) {
					json = await response.json();
					setTradesData(json);
				}
			} catch (error) {
				return error;
			}
		};
		fetchData();
	}, [accountId]);
	return tradesData;
}
