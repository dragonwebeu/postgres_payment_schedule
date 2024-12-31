CREATE OR REPLACE FUNCTION public.create_payment_schedule(IN start_date date,IN _monthly_payment integer,IN debt_amount double precision,IN contract_fee double precision DEFAULT 0, IN json_data JSONB DEFAULT '{}', IN _debug boolean DEFAULT false)
    RETURNS TABLE(payment_date date, balance double precision, payment_amount double precision, lump double precision, intress double precision, fines double precision, damage_comp double precision, ps_contract_fee double precision, ps_intrest double precision, ps_penalty double precision, state_fee double precision, representation_fee double precision, procedural_expense double precision)
    LANGUAGE 'plpgsql'    
    
AS $BODY$
DECLARE
    schedule_current_date DATE;
	schedule_contract_fee double precision;
    payment_interval INTERVAL := '1 month';
    interest_rate double precision := 0.00;
	fines_rate double precision := 0.0650;
	additional_fine double precision := 0;
    monthly_payment double precision;
    total_payments double precision;
	i integer := 0;	
	component_payment_order integer[];
  	json_value TEXT;	
	variable_name integer;
	amount double precision;
	paid double precision;
	pay double precision := 0;
	monthly_payment_residue double precision;
	row_payment_order JSONB;
	row_payment_order_return_data RECORD;	
	has_lump double precision;
	has_lump_paid double precision;
	add_to_fine double precision;
	calculated_fine double precision := 0;
	fine_days_interval INT;
	fine_next_payment_day DATE;
	_debug boolean;
BEGIN
	--json_data := '{"1":{"amount":809.6,"paid":0},"2":{"amount":390.4,"paid":0},"6":{"amount":20.0,"paid":0}}';
	-- Payment order, each number is some component
	RAISE NOTICE '%', json_data;
	component_payment_order := '{6,2,3,4,1,5,7,8}';
	-- Don't caluctate penalty
	fines_rate := 0;

    schedule_current_date := start_date + payment_interval;
	total_payments := (debt_amount + contract_fee);
	RAISE NOTICE 'total_payments: %', total_payments;
    monthly_payment := _monthly_payment;	
	debt_amount := debt_amount + contract_fee;	
    WHILE debt_amount > 0 LOOP
		ps_contract_fee := 0;
		lump := 0;
		fines := 0;
		damage_comp := 0;
		intress := 0;
		ps_contract_fee := 0;	
		-- Contract fee is on the first month/row
		-- Todo: the first row should be when the payment schedule is created
		IF i = 0 THEN
			ps_contract_fee := contract_fee;
			payment_amount := LEAST(debt_amount, monthly_payment+ps_contract_fee);
		ELSE
			payment_amount := LEAST(debt_amount, monthly_payment);
		END IF;
		-- Todo: Add penalty calculation!		
		debt_amount := debt_amount - payment_amount;
		has_lump := json_data->'1'::VARCHAR->>'amount';
		has_lump_paid := json_data->'1'::VARCHAR->>'paid';
		add_to_fine := json_data->'2'::VARCHAR->>'amount';		
		IF fines_rate > 0 AND debt_amount > 0 THEN
			RAISE NOTICE 'ADD future fine to graph';
			calculated_fine := 0;			
			IF has_lump > 0 THEN
				RAISE NOTICE 'has_lump: %, has_lump_paid: %', has_lump, has_lump_paid;				
				fine_next_payment_day := schedule_current_date + payment_interval;
				RAISE NOTICE 'schedule_current_date: %', schedule_current_date;
				fine_days_interval := fine_next_payment_day::DATE-schedule_current_date::DATE;
				RAISE NOTICE 'fine_next_payment_day: %', fine_next_payment_day;
				RAISE NOTICE 'fine_days_interval: %', fine_days_interval;
				calculated_fine := (((has_lump - has_lump_paid) * fines_rate) / 100) * fine_days_interval;
				IF calculated_fine > 0 THEN
					json_data := jsonb_set(json_data, concat('{2,amount}')::text[], to_jsonb(ROUND(CAST(add_to_fine+calculated_fine AS NUMERIC),2)));
					RAISE NOTICE 'json_data:%', json_data;
					debt_amount := ROUND(CAST(debt_amount + calculated_fine AS NUMERIC), 2);
				END IF;				
			END IF;			
		END IF;
		balance := ROUND(CAST(debt_amount AS NUMERIC),2);
		RAISE NOTICE 'payment_amount: %', payment_amount;
		monthly_payment_residue := payment_amount;				
        payment_date := schedule_current_date;        			
		RAISE NOTICE 'i:%', i;	
		SELECT * INTO row_payment_order_return_data FROM calculate_payments(json_data::JSONB, component_payment_order, monthly_payment_residue);
		RAISE NOTICE 'row_payment_order_return_data: %', row_payment_order_return_data;
		row_payment_order := (row_payment_order_return_data.row_payment_order);		
		json_data := row_payment_order_return_data.json_data;
		IF _debug THEN
			RAISE NOTICE 'row_payment_order: %', row_payment_order;
			RAISE NOTICE 'json_data: %', json_data;				
			RAISE NOTICE 'payment_date: %', payment_date;
			RAISE NOTICE 'debt_amount:%', debt_amount;	
			RAISE NOTICE 'row_payment_order: %', row_payment_order;
			RAISE NOTICE 'row_payment_order->6: %',row_payment_order->>'6';
			RAISE NOTICE 'row_payment_order->1: %',row_payment_order->>'1';
			RAISE NOTICE 'row_payment_order->2: %',row_payment_order->>'2';
		END IF;
	
		IF row_payment_order->>'1' IS NOT NULL THEN			
			lump := ROUND(CAST(row_payment_order->>'1' AS NUMERIC), 2);
		END IF;
		IF  row_payment_order->>'2' IS NOT NULL THEN
			fines := ROUND(CAST(row_payment_order->>'2' AS NUMERIC), 2);
		END IF;		
		IF row_payment_order->>'3' IS NOT NULL THEN
			damage_comp := ROUND(CAST(row_payment_order->>'3' AS NUMERIC), 2);
		END IF;
		IF  row_payment_order->>'4' IS NOT NULL THEN
			intress := ROUND(CAST(row_payment_order->>'4' AS NUMERIC), 2);
		END IF;
		IF  row_payment_order->>'5' IS NOT NULL THEN
		END IF;
		IF  row_payment_order->>'6' IS NOT NULL THEN
			ps_contract_fee := ROUND(CAST(row_payment_order->>'6' AS NUMERIC), 2);
		END IF;
        RETURN NEXT;	
		i = i+1;
        schedule_current_date := schedule_current_date + payment_interval;
		-- MAX 300 months = 25 years
		IF i = 300 THEN
			RAISE EXCEPTION 'Payment Schedule extend % months!', i;
			EXIT;
		END IF;
    END LOOP;
END; 
$BODY$;