--Prova finale di Reti Logiche
--Alessio Tommasi
--codice persona: 10706053
--matricola: 938346
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity project_reti_logiche is
    port (
    --generati ad test
        i_clk : in std_logic;--segnale di clock del componente sincrono
        i_rst : in std_logic;--segnale di reset
        i_start : in std_logic;--segnale che specifica quando abilitare lettura      
        i_w : in std_logic;--segnale che contiene dato desiderato
        --
        
        --contiene i dati letti dalla memoria a seguito di una richesta di lettura!
        i_mem_data : in std_logic_vector(7 downto 0);
        
        --canali di uscita
        o_z0 : out std_logic_vector(7 downto 0);
        o_z1 : out std_logic_vector(7 downto 0);
        o_z2 : out std_logic_vector(7 downto 0);
        o_z3 : out std_logic_vector(7 downto 0);
        
        --canali per comunicazione con la memoria
        o_done : out std_logic; -- segnale che ci dice se operazione lettura / scrittura e'finita. 
        o_mem_addr: out std_logic_vector(15 downto 0);--cella della memoria che voglio leggere!
        o_mem_we : out std_logic;--write enable: deve essere a 1 per poter scrivere sulla memoria! 0 per lettura
        o_mem_en : out std_logic -- dice che sto comunicando con memoria => sempre a 1 nelle fasi di lettura e scrittura!
        --
    );
end entity project_reti_logiche;

architecture behavioral of project_reti_logiche is
    type state_type is (
        IDLE,
        --stato di lettura di input i_w
        INPUT_FETCHING,
         --il componente memorizza la stringa di bit da elaborare in dati_di_w 
         -- e seleziona uscita se start e'alto per piu di 4 clock
        
        --STATI di elaborazione:
        CONVERSIONE_Z_1,
        CONVERSIONE_Z_2,
        CONVERSIONE_INDIRIZZO,
        
        --stati per leggere fa memoria 
        INPUT_ADDRESS_FETCHING,--fornire alla memoria l'indirizzo della cella che contiene la stringa di bit da convertire 
        -- > deve diventare fornire alla memoria l'indirizzo della cella che contiene il calane_uscita | dato da scrivere in out 
        INPUT_ADDRESS_WAIT_FOR_RAM, 
        SAVE_INPUT_ADDRESS,
        
        --stato necessario per la scrittura delle uscite
        SCRIVI_OUT,
        DONE--stato che rimette a 0 le uscite e dice che ho finito di fare elaborazioni su di esse (Done =0)!!
    );
    
        signal current_state: state_type; --segnale che ci indica in che stato siamo 
        
        signal address_saved,flag_conv: boolean ;
        --flag_conv: mi dice se necessito di fare conversione o meno 
        --(ottimizzazione dei cicli di clock in base alla grandezza dell input letto)
         
        signal final_out: std_logic_vector(7 downto 0);--SEGNALE CHE CONTIENE i dati da scrivere nel canale di uscita!
        
        --segnali che servono per memorizzare i valori assegnati alle precedenti uscite
        signal prec_z0: std_logic_vector(7 downto 0):= (others => '0');
        signal prec_z1: std_logic_vector(7 downto 0) := (others => '0');
        signal prec_z2: std_logic_vector(7 downto 0) := (others => '0');
        signal prec_z3: std_logic_vector(7 downto 0) := (others => '0');
        --end prec signal 
        
        signal dati_di_i_w : std_logic_vector(17 downto 0) := (others => '0');
        --deve essere downto poiche il bit pio significativo (quello letto prima) e' memorizzato nella posizione 17!!!
        
        signal contatore_in: natural := 0; --mi dice per quanto start e'stato alto
        signal canale_out : natural := 0;--seleziona il canale di uscita da utilizzare
        
        signal address_to_read : std_logic_vector(15 downto 0) := (others => '0');
        --segnale in cui metto indirizzo di memoria di cui voglio leggere il contenuto per poi scriverlo sulle uscite
        
    begin
        mainProcess: process (i_clk, i_rst)
        begin
            if (i_rst = '1') then 
                --Quando il segnale DONE è 0 tutti i canali Z0, Z1, Z2 e Z3 devono essere a zero (32 bit a 0).
                o_z0 <= (others => '0');
                o_z1 <= (others => '0');
                o_z2 <= (others => '0');
                o_z3 <= (others => '0');
                --solo in reset
                prec_z0  <= (others => '0');
                prec_z1  <= (others => '0');
                prec_z2  <= (others => '0');
                prec_z3  <= (others => '0');
                
                dati_di_i_w<= (others => '0');
                address_to_read <= (others => '0');
                --in ogni ramo dell if devo mettere tutti i segnali che vengono modificati!!!
                --done vie modificato solo al cc successivo alla lettura!
                o_mem_en <= '0';--disabilito memoria
                o_mem_we <= '0';--0 = lettura 1 = scrittura!
                o_done <= '0'; --anche se non sto usndo memoria da specifica e' 0!!
               
               --di sistena
                address_saved <= false;
                flag_conv <= false;
                contatore_in <= 17; 
                canale_out <= 0;
                
                current_state <= IDLE;
                
            elsif(rising_edge(i_clk)) then --siccome componente sincrono e non latch metto tutto eseguito ad ogni istruzione del cc
                case current_state is
                    when IDLE =>
                    o_z0 <= (others => '0');
                    o_z1 <= (others => '0');
                    o_z2 <= (others => '0');
                    o_z3 <= (others => '0');
                    flag_conv <= false;
                    
                      if (i_start = '1') then
                          current_state <= INPUT_FETCHING;
                          --devo metterlo qui se no non leggo il primo bit!!
                          dati_di_i_w(17) <= i_w;
                           if (contatore_in < 0) then
                              contatore_in <= 0; -- assegnazione del valore minimo consentito
                            elsif (contatore_in > 255) then
                              contatore_in <= 255; -- assegnazione del valore massimo consentito
                            else
                              contatore_in <= contatore_in -1;
                            end if;
                      end if;
                      
                    
                    when INPUT_FETCHING =>
                      --lettura dell input
                      if (i_start = '1') then
                        case contatore_in is
                            when 0 => --non serve!! se tutto giusto qui non ci entro mai!!
                                dati_di_i_w(0) <= i_w;
                            when 1 => 
                                dati_di_i_w(1) <= i_w;
                            when 2 => 
                                dati_di_i_w(2) <= i_w;
                            when 3 => 
                                dati_di_i_w(3) <= i_w;
                            when 4 => 
                                dati_di_i_w(4) <= i_w;
                            when 5 => 
                                dati_di_i_w(5) <= i_w;
                            when 6 => 
                                dati_di_i_w(6) <= i_w;
                            when 7 => 
                                dati_di_i_w(7) <= i_w;
                            when 8 => 
                                dati_di_i_w(8) <= i_w;
                            when 9 => 
                                dati_di_i_w(9) <= i_w;
                            when 10 => 
                                dati_di_i_w(10) <= i_w;
                            when 11 => 
                                dati_di_i_w(11) <= i_w;
                            when 12 => 
                                dati_di_i_w(12) <= i_w;
                            when 13 => 
                                dati_di_i_w(13) <= i_w;
                            when 14 => 
                                dati_di_i_w(14) <= i_w;                                
                                --prova per vedere se servono piu cc
                                 if(dati_di_i_w(16) = '1') then
                                    canale_out <= canale_out +1;
                                 end if;
                                 flag_conv <= true;
                                --fine conv canale out!!!
                            when 15 => 
                                dati_di_i_w(15) <= i_w;
                                --trovo canale di uscita!! la faccio qui per risparmiarmi 2 cc!!
                                if(dati_di_i_w(17) = '1') then
                                    canale_out <= canale_out +2;
                                end if;
                            when 16 => 
                                dati_di_i_w(16) <= i_w;             
                            when others =>--non dovrebbe mai capitare
                                dati_di_i_w(17) <= i_w;
                      end case;
                        if (contatore_in < 0) then
                          contatore_in <= 0; -- assegnazione del valore minimo consentito
                        elsif (contatore_in > 255) then
                          contatore_in <= 255; -- assegnazione del valore massimo consentito
                        else
                          contatore_in <= contatore_in -1;
                        end if;
                        else 
                            if(flag_conv = true) then
                                    current_state <= CONVERSIONE_INDIRIZZO;
                                else
                                    current_state <= CONVERSIONE_Z_1;
                            end if;
                      end if;
                    
                    when CONVERSIONE_Z_1 =>
                      --lettura dell input
                        --conversione in decimale                        
                        if(dati_di_i_w(17) = '1') then
                            canale_out <= 2;
                        end if;
                        
                        current_state <= CONVERSIONE_Z_2;
                     when CONVERSIONE_Z_2 =>
                      --lettura dell input
                        flag_conv <= true;
                        --conversione in decimale                        
                        if(dati_di_i_w(16) = '1') then
                            canale_out <= canale_out +1;
                        end if;
                        
                        current_state <= CONVERSIONE_INDIRIZZO;
                    
                    when CONVERSIONE_INDIRIZZO =>
                      address_to_read <= std_logic_vector(resize(unsigned(dati_di_i_w(15 downto contatore_in + 1)), 16));
                      
                      current_state <= INPUT_ADDRESS_FETCHING;
                     
                      
                      
                      
                      
                    when INPUT_ADDRESS_FETCHING   =>
                      o_mem_en <= '1';--abilito l utilizzo della memoria
                      o_mem_we <= '0';--metto memoria in lettura
                      if (not address_saved) then        
                          o_mem_addr <= address_to_read;
                      end if;
                      current_state <= INPUT_ADDRESS_WAIT_FOR_RAM;
                      
                    when INPUT_ADDRESS_WAIT_FOR_RAM   =>
                      if (address_saved) then                  
                          current_state <= SCRIVI_OUT;                    
                          
                      else
                          current_state <=  SAVE_INPUT_ADDRESS;   
                      end if;
                      
                    when SAVE_INPUT_ADDRESS   =>
                    
                      if (not address_saved) then
                          final_out <= i_mem_data;
                          address_saved <= true;
                          current_state <= INPUT_ADDRESS_WAIT_FOR_RAM;
                          
                      else
                          current_state  <= SCRIVI_OUT;
                      end if;
                    
                    
                    
                    when SCRIVI_OUT =>
                        o_done <= '1';
                        
                        case canale_out is
                            when 0 =>
                                o_z0 <= final_out;
                                prec_z0 <= final_out;
                                
                                o_z1 <= prec_z1;
                                o_z2 <= prec_z2;
                                o_z3 <= prec_z3;
                                
                                --rimetto i segnali precedenti!!!
                            when 1 =>
                                o_z1 <= final_out;
                                prec_z1 <= final_out;
                                
                                o_z0 <= prec_z0;
                                o_z2 <= prec_z2;
                                o_z3 <= prec_z3;
                            when 2 =>
                                o_z2 <= final_out;
                                prec_z2 <= final_out;
                                
                                o_z1 <= prec_z1;
                                o_z0 <= prec_z0;
                                o_z3 <= prec_z3;
                            when 3 =>
                                o_z3 <= final_out;
                                prec_z3 <= final_out;
                                
                                o_z1 <= prec_z1;
                                o_z2 <= prec_z2;
                                o_z0 <= prec_z0;
                            when others =>--non capita mai ma caga il cazz se non lo metto
                                o_z3 <= final_out;
                                prec_z3 <= final_out;
                        end case;
                       
                        current_state <= DONE;
                         
                    when DONE =>
                      --if (i_start = '0') then --altrimenti non sono riuscito a fare conversione in tempo!!!
                            --copia dello stato di reset!!
                            --Quando il segnale DONE è 0 tutti i canali Z0, Z1, Z2 e Z3 devono essere a zero (32 bit a 0).
                            o_z0 <= (others => '0');
                            o_z1 <= (others => '0');
                            o_z2 <= (others => '0');
                            o_z3 <= (others => '0');
                            
                            dati_di_i_w<= (others => '0');
                            address_to_read <= (others => '0');
                            --in ogni ramo dell if devo mettere tutti i segnali che vengono modificati!!!
                            --done vie modificato solo al cc successivo alla lettura!
                            o_mem_en <= '0';--disabilito memoria
                            o_mem_we <= '0';--0 = lettura 1 = scrittura!
                            o_done <= '0'; --anche se non sto usndo memoria da specifica e' 0!!
                           
                           --di sistena
                            address_saved <= false;
                            flag_conv <= false;
                            contatore_in <= 17; 
                            canale_out <= 0;
                            
                            current_state <= IDLE;
                      --end if;
                end case;
            end if;    
        end process;
end architecture behavioral;






















