# Preparing Public Health Surveillance data for ADaM submission 

This project simulates an ADaM-style analysis pipeline using publicly available BRFSS 2022 data. It focuses on chronic condition burden and physical health outcomes, stratified by age group, and demonstrates reproducible workflow design aligned with regulatory and public health standards.

## What's Included

- **SAS Program**: `Preparing BRFSS for ADaM submission.sas`  
- **Subset Data**: `brfss_subset.csv`  
- **Metadata Documentation**: `adam_metadata.xlsx`  
- **Mock TLF Output**: `Table1_TLF.xlsx`  
- **Dashboard Formatted 2×2 Table**: `Table1_dashboardfmt.xlsx`  

## Additional Modifications

- Derived flags for arthritis status and poor physical health (≥15 days)
- Age stratification using BRFSS categorical age variable
- Survey-weighted analysis using `PROC SURVEYFREQ` with strata, PSU, and final weights
- Metadata table simulating define.xml structure with variable-level documentation

## How to Reproduce

To regenerate the analysis and outputs:

1. Clone the repository
2. Open `Preparing BRFSS for ADaM submission.sas` in SAS OnDemand or local SAS
3. Ensure `brfss_subset.csv` is available in your working directory
4. Run the full program to generate metadata, mock TLF, and formatted outputs

> Note: This project uses manual control over table formatting and metadata documentation to simulate ADaM-style traceability and reproducibility.

## 👩‍🔬 Author

**Lindsay Trujillo, PhD, MPH**  
Senior Data Scientist & Epidemiologist  
Specializing in reproducible analytics, regulatory documentation, and data simulation for clinical and public health applications.

### Suggested Citation

Trujillo L. *Preparing Public Health Surveillance data for ADaM submission*. GitHub. September 2025.

## 📜 License

This project workflow is released under the MIT License. See `LICENSE` for 
